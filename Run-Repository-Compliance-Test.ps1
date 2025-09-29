#requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive compliance test for all repositories after MUW-Regelwerk v9.6.0 consolidation
.DESCRIPTION
    Validates all repositories in F:\DEV\repositories\ for compliance with MUW-Regelwerk v9.6.0
    Tests naming conventions (§18), repository organization (§19), and script interoperability (§20)
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.0.0
    Regelwerk: v9.6.0
    Created: 2025-09-27
#>

Write-Host "🔍 MUW-Regelwerk v9.6.0 - REPOSITORY COMPLIANCE VALIDATOR" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Gray
Write-Host "📅 Test Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "📂 Testing Directory: F:\DEV\repositories\" -ForegroundColor Cyan

$RepositoryPath = "F:\DEV\repositories"
$TestResults = @()
$TotalScore = 0
$MaxScore = 0

# Repository definitions with expected compliance levels
$Repositories = @(
    @{Name = "CertSurv"; ExpectedCompliance = 98; IsCritical = $true},
    @{Name = "ResetProfile"; ExpectedCompliance = 95; IsCritical = $false},
    @{Name = "Useranlage"; ExpectedCompliance = 92; IsCritical = $false},
    @{Name = "CertWebService"; ExpectedCompliance = 90; IsCritical = $false},
    @{Name = "GitCache"; ExpectedCompliance = 85; IsCritical = $false},
    @{Name = "Tests"; ExpectedCompliance = 88; IsCritical = $false}
)

function Test-RepositoryCompliance {
    param(
        [string]$RepoName,
        [string]$RepoPath,
        [int]$ExpectedCompliance
    )
    
    Write-Host "`n🔧 Testing Repository: $RepoName" -ForegroundColor Yellow
    
    $ComplianceScore = 0
    $MaxComplianceScore = 20  # Total possible points
    $Details = @()
    
    # Test §19.1: Standard Directory Structure (5 points)
    $RequiredDirs = @("Config", "Modules", "LOG", "TEST", "Docs", "old")
    $DirsFound = 0
    
    foreach ($Dir in $RequiredDirs) {
        $DirPath = Join-Path $RepoPath $Dir
        if (Test-Path $DirPath) {
            $DirsFound++
            $Details += "✅ Directory $Dir exists"
        } else {
            $Details += "❌ Directory $Dir missing"
        }
    }
    
    $DirScore = [math]::Round(($DirsFound / $RequiredDirs.Count) * 5)
    $ComplianceScore += $DirScore
    
    # Test §18.1: VERSION.ps1 exists (3 points)
    $VersionFile = Join-Path $RepoPath "VERSION.ps1"
    if (Test-Path $VersionFile) {
        try {
            $VersionContent = Get-Content $VersionFile -Raw
            if ($VersionContent -match "v9\.6\.0") {
                $ComplianceScore += 3
                $Details += "✅ VERSION.ps1 exists with v9.6.0 compliance"
            } else {
                $ComplianceScore += 1
                $Details += "⚠️ VERSION.ps1 exists but may not be v9.6.0 compliant"
            }
        } catch {
            $ComplianceScore += 1
            $Details += "⚠️ VERSION.ps1 exists but could not be validated"
        }
    } else {
        $Details += "❌ VERSION.ps1 missing"
    }
    
    # Test §18.1: FL-* Module naming convention (4 points)
    $ModulesPath = Join-Path $RepoPath "Modules"
    if (Test-Path $ModulesPath) {
        $FLModules = Get-ChildItem -Path $ModulesPath -Filter "FL-*.psm1" -ErrorAction SilentlyContinue
        if ($FLModules.Count -gt 0) {
            $ModuleScore = [math]::Min(4, $FLModules.Count)
            $ComplianceScore += $ModuleScore
            $Details += "✅ FL-* modules found: $($FLModules.Count)"
        } else {
            $Details += "❌ No FL-* modules found"
        }
    } else {
        $Details += "❌ Modules directory missing"
    }
    
    # Test §20.3: Cross-Script Communication (4 points)
    $UtilsModule = Join-Path $ModulesPath "FL-Utils.psm1"
    if (Test-Path $UtilsModule) {
        try {
            $UtilsContent = Get-Content $UtilsModule -Raw
            $CommunicationScore = 0
            
            if ($UtilsContent -match "Send-ScriptMessage") {
                $CommunicationScore++
                $Details += "✅ Send-ScriptMessage function found"
            }
            if ($UtilsContent -match "Set-ScriptStatus") {
                $CommunicationScore++
                $Details += "✅ Set-ScriptStatus function found"
            }
            if ($UtilsContent -match "Get-ScriptStatus") {
                $CommunicationScore++
                $Details += "✅ Get-ScriptStatus function found"
            }
            if ($UtilsContent -match "v9\.6\.0") {
                $CommunicationScore++
                $Details += "✅ v9.6.0 compliance in FL-Utils"
            }
            
            $ComplianceScore += $CommunicationScore
        } catch {
            $Details += "⚠️ FL-Utils.psm1 could not be analyzed"
        }
    } else {
        $Details += "❌ FL-Utils.psm1 not found"
    }
    
    # Test §19.1: Configuration structure (2 points)
    $ConfigPath = Join-Path $RepoPath "Config"
    if (Test-Path $ConfigPath) {
        $ConfigFiles = Get-ChildItem -Path $ConfigPath -Filter "*.json" -ErrorAction SilentlyContinue
        if ($ConfigFiles.Count -gt 0) {
            $ComplianceScore += 2
            $Details += "✅ JSON configuration files found: $($ConfigFiles.Count)"
        } else {
            $ComplianceScore += 1
            $Details += "⚠️ Config directory exists but no JSON files found"
        }
    } else {
        $Details += "❌ Config directory missing"
    }
    
    # Test §19.1: TEST directory with test scripts (2 points)
    $TestPath = Join-Path $RepoPath "TEST"
    if (Test-Path $TestPath) {
        $TestFiles = Get-ChildItem -Path $TestPath -Filter "Test-*.ps1" -ErrorAction SilentlyContinue
        if ($TestFiles.Count -gt 0) {
            $ComplianceScore += 2
            $Details += "✅ Test scripts found: $($TestFiles.Count)"
        } else {
            $ComplianceScore += 1
            $Details += "⚠️ TEST directory exists but no Test-*.ps1 files found"
        }
    } else {
        $Details += "❌ TEST directory missing"
    }
    
    # Calculate percentage
    $CompliancePercentage = [math]::Round(($ComplianceScore / $MaxComplianceScore) * 100)
    
    # Determine status
    $Status = if ($CompliancePercentage -ge $ExpectedCompliance) { "✅ PASS" } 
              elseif ($CompliancePercentage -ge 70) { "⚠️ ACCEPTABLE" } 
              else { "❌ NEEDS WORK" }
    
    # Color coding for output
    $StatusColor = if ($CompliancePercentage -ge $ExpectedCompliance) { "Green" } 
                   elseif ($CompliancePercentage -ge 70) { "Yellow" } 
                   else { "Red" }
    
    Write-Host "   📊 Score: $ComplianceScore/$MaxComplianceScore ($CompliancePercentage%) - $Status" -ForegroundColor $StatusColor
    
    return @{
        Repository = $RepoName
        Score = $ComplianceScore
        MaxScore = $MaxComplianceScore
        Percentage = $CompliancePercentage
        Expected = $ExpectedCompliance
        Status = $Status
        Details = $Details
    }
}

# Test all repositories
foreach ($Repo in $Repositories) {
    $RepoPath = Join-Path $RepositoryPath $Repo.Name
    
    if (Test-Path $RepoPath) {
        $Result = Test-RepositoryCompliance -RepoName $Repo.Name -RepoPath $RepoPath -ExpectedCompliance $Repo.ExpectedCompliance
        $TestResults += $Result
        $TotalScore += $Result.Score
        $MaxScore += $Result.MaxScore
    } else {
        Write-Host "`n❌ Repository not found: $($Repo.Name)" -ForegroundColor Red
        $TestResults += @{
            Repository = $Repo.Name
            Score = 0
            MaxScore = 20
            Percentage = 0
            Expected = $Repo.ExpectedCompliance
            Status = "❌ NOT FOUND"
            Details = @("Repository directory missing")
        }
        $MaxScore += 20
    }
}

# Generate summary report
Write-Host "`n" + "=" * 80 -ForegroundColor Gray
Write-Host "📊 REPOSITORY COMPLIANCE SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Gray

$OverallPercentage = [math]::Round(($TotalScore / $MaxScore) * 100)
$PassedRepos = ($TestResults | Where-Object { $_.Status -eq "✅ PASS" }).Count
$TotalRepos = $TestResults.Count

foreach ($Result in $TestResults) {
    $StatusIcon = switch ($Result.Status) {
        "✅ PASS" { "✅" }
        "⚠️ ACCEPTABLE" { "⚠️" }
        "❌ NEEDS WORK" { "❌" }
        "❌ NOT FOUND" { "❌" }
        default { "❓" }
    }
    
    $StatusColor = switch ($Result.Status) {
        "✅ PASS" { "Green" }
        "⚠️ ACCEPTABLE" { "Yellow" }
        default { "Red" }
    }
    
    Write-Host "$StatusIcon $($Result.Repository): $($Result.Percentage)% (Expected: $($Result.Expected)%)" -ForegroundColor $StatusColor
}

Write-Host "`n🎯 OVERALL RESULTS:" -ForegroundColor Cyan
Write-Host "   Total Score: $TotalScore/$MaxScore ($OverallPercentage%)" -ForegroundColor $(if($OverallPercentage -ge 90){"Green"}elseif($OverallPercentage -ge 70){"Yellow"}else{"Red"})
Write-Host "   Repositories Passed: $PassedRepos/$TotalRepos" -ForegroundColor $(if($PassedRepos -eq $TotalRepos){"Green"}else{"Yellow"})
Write-Host "   MUW-Regelwerk v9.6.0 Compliance: $(if($OverallPercentage -ge 90){"✅ EXCELLENT"}elseif($OverallPercentage -ge 80){"✅ GOOD"}elseif($OverallPercentage -ge 70){"⚠️ ACCEPTABLE"}else{"❌ NEEDS IMPROVEMENT"})" -ForegroundColor $(if($OverallPercentage -ge 80){"Green"}elseif($OverallPercentage -ge 70){"Yellow"}else{"Red"})

# Critical systems check
$CriticalRepos = $Repositories | Where-Object { $_.IsCritical }
$CriticalResults = $TestResults | Where-Object { $_.Repository -in $CriticalRepos.Name }
$CriticalPassed = ($CriticalResults | Where-Object { $_.Status -eq "✅ PASS" }).Count

Write-Host "`n🚨 CRITICAL SYSTEMS STATUS:" -ForegroundColor Cyan
foreach ($Critical in $CriticalResults) {
    $CriticalColor = if ($Critical.Status -eq "✅ PASS") { "Green" } else { "Red" }
    Write-Host "   🔴 $($Critical.Repository): $($Critical.Status)" -ForegroundColor $CriticalColor
}

if ($CriticalPassed -eq $CriticalRepos.Count) {
    Write-Host "`n🎉 ALL CRITICAL SYSTEMS ARE COMPLIANT!" -ForegroundColor Green
    Write-Host "   Production deployment is APPROVED ✅" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ CRITICAL SYSTEMS NEED ATTENTION!" -ForegroundColor Red
    Write-Host "   Review required before production deployment ❌" -ForegroundColor Red
}

# Detailed report for failed/warning repositories
$ProblematicRepos = $TestResults | Where-Object { $_.Status -ne "✅ PASS" }
if ($ProblematicRepos.Count -gt 0) {
    Write-Host "`n📋 DETAILED ISSUES:" -ForegroundColor Yellow
    foreach ($Repo in $ProblematicRepos) {
        Write-Host "`n   🔍 $($Repo.Repository):" -ForegroundColor Yellow
        foreach ($Detail in $Repo.Details) {
            if ($Detail.StartsWith("❌") -or $Detail.StartsWith("⚠️")) {
                Write-Host "      $Detail" -ForegroundColor $(if($Detail.StartsWith("❌")){"Red"}else{"Yellow"})
            }
        }
    }
}

# Final recommendations
Write-Host "`n💡 RECOMMENDATIONS:" -ForegroundColor Cyan
if ($OverallPercentage -ge 90) {
    Write-Host "   ✅ Excellent compliance achieved!" -ForegroundColor Green
    Write-Host "   ✅ All repositories are production-ready" -ForegroundColor Green
    Write-Host "   📋 Consider scheduling regular compliance checks" -ForegroundColor Cyan
} elseif ($OverallPercentage -ge 80) {
    Write-Host "   ✅ Good compliance level achieved" -ForegroundColor Green
    Write-Host "   📋 Address minor issues in non-critical repositories" -ForegroundColor Yellow
    Write-Host "   📋 Schedule compliance review in 30 days" -ForegroundColor Cyan
} else {
    Write-Host "   ⚠️ Significant improvements needed" -ForegroundColor Red
    Write-Host "   📋 Focus on repositories below 80% compliance" -ForegroundColor Red
    Write-Host "   📋 Re-run consolidation process for failing repositories" -ForegroundColor Red
}

Write-Host "`n" + "=" * 80 -ForegroundColor Gray
Write-Host "✅ Compliance test completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "📊 Report saved to: Repository-Compliance-Test-Results.json" -ForegroundColor Cyan

# Save detailed results to JSON
$TestResults | ConvertTo-Json -Depth 10 | Out-File "Repository-Compliance-Test-Results.json" -Encoding UTF8