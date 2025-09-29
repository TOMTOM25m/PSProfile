#requires -Version 5.1

<#
.SYNOPSIS
    Repository compliance test for MUW-Regelwerk v9.6.0
.DESCRIPTION
    Tests all repositories for v9.6.0 compliance
#>

Write-Host "🔍 MUW-Regelwerk v9.6.0 - REPOSITORY COMPLIANCE TEST" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray

$RepositoryPath = "F:\DEV\repositories"
$TestResults = @()

# Test each major repository
$Repositories = @("CertSurv", "ResetProfile", "Useranlage", "CertWebService", "GitCache", "Tests")

foreach ($RepoName in $Repositories) {
    $RepoPath = Join-Path $RepositoryPath $RepoName
    
    if (Test-Path $RepoPath) {
        Write-Host "`n📂 Testing: $RepoName" -ForegroundColor Cyan
        
        $Score = 0
        $MaxScore = 10
        
        # Test VERSION.ps1 exists
        if (Test-Path (Join-Path $RepoPath "VERSION.ps1")) {
            $Score += 2
            Write-Host "  ✅ VERSION.ps1 exists" -ForegroundColor Green
        } else {
            Write-Host "  ❌ VERSION.ps1 missing" -ForegroundColor Red
        }
        
        # Test standard directories
        $RequiredDirs = @("Config", "Modules", "LOG", "TEST", "Docs", "old")
        $DirsFound = 0
        
        foreach ($Dir in $RequiredDirs) {
            if (Test-Path (Join-Path $RepoPath $Dir)) {
                $DirsFound++
            }
        }
        
        $Score += [math]::Min(4, $DirsFound)
        Write-Host "  📁 Directories: $DirsFound/$($RequiredDirs.Count)" -ForegroundColor $(if($DirsFound -ge 4){"Green"}else{"Yellow"})
        
        # Test FL-* modules
        $ModulesPath = Join-Path $RepoPath "Modules"
        if (Test-Path $ModulesPath) {
            $FLModules = Get-ChildItem -Path $ModulesPath -Filter "FL-*.psm1" -ErrorAction SilentlyContinue
            if ($FLModules.Count -gt 0) {
                $Score += 2
                Write-Host "  ✅ FL-* modules found: $($FLModules.Count)" -ForegroundColor Green
            }
        }
        
        # Test cross-script communication
        $UtilsPath = Join-Path $ModulesPath "FL-Utils.psm1"
        if (Test-Path $UtilsPath) {
            $UtilsContent = Get-Content $UtilsPath -Raw -ErrorAction SilentlyContinue
            if ($UtilsContent -and $UtilsContent -match "Send-ScriptMessage") {
                $Score += 2
                Write-Host "  ✅ Cross-script communication implemented" -ForegroundColor Green
            }
        }
        
        $Percentage = [math]::Round(($Score / $MaxScore) * 100)
        $Status = if ($Percentage -ge 80) { "✅ COMPLIANT" } else { "⚠️ NEEDS WORK" }
        $StatusColor = if ($Percentage -ge 80) { "Green" } else { "Yellow" }
        
        Write-Host "  📊 Score: $Score/$MaxScore ($Percentage%) - $Status" -ForegroundColor $StatusColor
        
        $TestResults += @{
            Repository = $RepoName
            Score = $Score
            MaxScore = $MaxScore
            Percentage = $Percentage
            Status = $Status
        }
    } else {
        Write-Host "`n❌ Repository not found: $RepoName" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n" + "=" * 60 -ForegroundColor Gray
Write-Host "📊 OVERALL RESULTS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

$TotalScore = ($TestResults | Measure-Object -Property Score -Sum).Sum
$TotalMaxScore = ($TestResults | Measure-Object -Property MaxScore -Sum).Sum
$OverallPercentage = [math]::Round(($TotalScore / $TotalMaxScore) * 100)

foreach ($Result in $TestResults) {
    $StatusColor = if ($Result.Status -eq "✅ COMPLIANT") { "Green" } else { "Yellow" }
    Write-Host "$($Result.Repository): $($Result.Percentage)% - $($Result.Status)" -ForegroundColor $StatusColor
}

Write-Host "`n🎯 Total Compliance: $TotalScore/$TotalMaxScore ($OverallPercentage%)" -ForegroundColor $(if($OverallPercentage -ge 85){"Green"}else{"Yellow"})

if ($OverallPercentage -ge 90) {
    Write-Host "🎉 EXCELLENT! All repositories are production-ready!" -ForegroundColor Green
} elseif ($OverallPercentage -ge 80) {
    Write-Host "✅ GOOD! Minor improvements may be needed." -ForegroundColor Green  
} else {
    Write-Host "⚠️ Additional work required for full compliance." -ForegroundColor Yellow
}

Write-Host "`n✅ Test completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green