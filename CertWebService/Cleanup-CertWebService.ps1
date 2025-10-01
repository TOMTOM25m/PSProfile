<#
.SYNOPSIS
    Directory Cleanup Script for CertWebService
    
.DESCRIPTION
    Cleans up outdated files, old documentation, and legacy scripts
    while preserving core functionality and current deployment tools.
    
.PARAMETER WhatIf
    Shows what would be cleaned up without actually deleting
    
.PARAMETER Force
    Force cleanup without confirmation
    
.EXAMPLE
    .\Cleanup-CertWebService.ps1 -WhatIf
    .\Cleanup-CertWebService.ps1 -Force
    
.NOTES
    Version: 1.0.0
    ITSC020 Workstation Tool
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "🧹 CERTWEBSERVICE DIRECTORY CLEANUP" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Define files/folders to clean up
$cleanupItems = @{
    "Outdated Documentation" = @(
        "SIMPLIFICATION-PLAN.md",
        "SIMPLIFICATION-COMPLETE.md",
        "REGELWERK-v9.6.2-IMPLEMENTATION.md",
        "README-Enhanced.txt",
        "ACL-SECURITY-GUIDE.md",
        "READ-ONLY-ACCESS-GUIDE.md",
        "INSTALLATION-TEST-LOG.md",
        "UNC-PATH-INSTALLATION-GUIDE.md",
        "DIRECTORY-CLEANUP-SUMMARY.md",
        "POWERSHELL-7X-COMPATIBILITY-FIX.md",
        "UNIVERSAL-POWERSHELL-COMPATIBILITY-FINAL.md",
        "EXECUTION-POLICY-SOLUTIONS.md",
        "PATH-PROBLEM-GELÖST.md",
        "DEPLOYMENT-SUCCESS-REPORT.md",
        "CREDENTIAL-MANAGEMENT.md"
    )
    
    "Legacy Scripts" = @(
        "Setup.ps1",
        "Update.ps1",
        "Remove.ps1",
        "Install.bat",
        "Setup-ACL-Config.ps1",
        "Setup-Universal-Compatible.ps1",
        "Deploy-ScanScript-Quick.ps1",
        "Deploy-CertWebService.ps1",
        "Deploy-CertWebService-PS5.ps1",
        "Deploy-CertWebService-PS7.ps1",
        "Setup-Remote-ScheduledTask-wsus.ps1",
        "Test-CredentialManager.ps1"
    )
    
    "Network Deployment (Legacy)" = @(
        "Create-NetworkDeployment.ps1",
        "Deploy-NetworkPackage.ps1"
    )
    
    "Old Scanning Scripts" = @(
        "Setup-ScheduledTask-CertScan.ps1",
        "ScanCertificates.ps1"
    )
    
    "Directories to Clean" = @(
        "TEST",
        "old"
    )
}

# Keep these important files
$keepFiles = @(
    "README.md",
    "VERSION.ps1",
    "CertWebService-Installer.ps1",
    "Deploy-CertWebService-FromExcel.ps1",
    "Deploy-FromExcel-PS5.ps1",
    "Deploy-FromExcel-PS7.ps1",
    "Manage-CertWebService-Updates.ps1",
    "Modules",
    "Config",
    "WebFiles",
    ".git"
)

Write-Host "📋 CLEANUP PLAN:" -ForegroundColor Yellow
Write-Host "────────────────" -ForegroundColor Gray

$totalItems = 0
foreach ($category in $cleanupItems.Keys) {
    Write-Host ""
    Write-Host "🗂️  $category:" -ForegroundColor Cyan
    
    foreach ($item in $cleanupItems[$category]) {
        $fullPath = Join-Path $ScriptDir $item
        if (Test-Path $fullPath) {
            $totalItems++
            if ((Get-Item $fullPath).PSIsContainer) {
                $itemCount = (Get-ChildItem $fullPath -Recurse -File).Count
                Write-Host "  📁 $item/ ($itemCount files)" -ForegroundColor Yellow
            } else {
                $size = [math]::Round((Get-Item $fullPath).Length / 1KB, 1)
                Write-Host "  📄 $item ($size KB)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ❌ $item (not found)" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "📊 SUMMARY:" -ForegroundColor Cyan
Write-Host "────────────" -ForegroundColor Gray
Write-Host "Items to clean: $totalItems" -ForegroundColor Yellow
Write-Host ""

Write-Host "✅ KEEPING THESE IMPORTANT FILES:" -ForegroundColor Green
Write-Host "──────────────────────────────────" -ForegroundColor Gray
foreach ($keepFile in $keepFiles) {
    $fullPath = Join-Path $ScriptDir $keepFile
    if (Test-Path $fullPath) {
        if ((Get-Item $fullPath).PSIsContainer) {
            Write-Host "  📁 $keepFile/" -ForegroundColor Green
        } else {
            Write-Host "  📄 $keepFile" -ForegroundColor Green
        }
    }
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "🔍 WHATIF MODE - No files will be deleted" -ForegroundColor Blue
    Write-Host "Run without -WhatIf to perform actual cleanup" -ForegroundColor Blue
    exit 0
}

Write-Host ""
if (-not $Force) {
    $confirmation = Read-Host "❓ Do you want to proceed with cleanup? (y/N)"
    if ($confirmation -notmatch '^[Yy]') {
        Write-Host "❌ Cleanup cancelled" -ForegroundColor Red
        exit 0
    }
}

Write-Host ""
Write-Host "🧹 Starting cleanup..." -ForegroundColor Cyan
Write-Host "──────────────────────" -ForegroundColor Gray

$deletedItems = 0
$errors = @()

foreach ($category in $cleanupItems.Keys) {
    Write-Host ""
    Write-Host "🗂️  Cleaning $category..." -ForegroundColor Cyan
    
    foreach ($item in $cleanupItems[$category]) {
        $fullPath = Join-Path $ScriptDir $item
        if (Test-Path $fullPath) {
            try {
                if ((Get-Item $fullPath).PSIsContainer) {
                    Remove-Item $fullPath -Recurse -Force
                    Write-Host "  ✅ Deleted folder: $item" -ForegroundColor Green
                } else {
                    Remove-Item $fullPath -Force
                    Write-Host "  ✅ Deleted file: $item" -ForegroundColor Green
                }
                $deletedItems++
            } catch {
                $errors += "Failed to delete $item`: $($_.Exception.Message)"
                Write-Host "  ❌ Failed to delete: $item" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
Write-Host "🎯 CLEANUP RESULTS:" -ForegroundColor Cyan
Write-Host "───────────────────" -ForegroundColor Gray
Write-Host "Items deleted: $deletedItems" -ForegroundColor Green
Write-Host "Errors: $($errors.Count)" -ForegroundColor $(if ($errors.Count -gt 0) { "Red" } else { "Green" })

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ ERRORS:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
}

# Create cleanup summary
$summaryPath = Join-Path $ScriptDir "CLEANUP-COMPLETED-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
$summary = @"
# CertWebService Directory Cleanup Report

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Items Deleted:** $deletedItems
**Errors:** $($errors.Count)

## Remaining Core Files:
- ✅ CertWebService-Installer.ps1 (Main installer)
- ✅ Deploy-CertWebService-FromExcel.ps1 (Smart loader)
- ✅ Deploy-FromExcel-PS5.ps1 (PS5 deployment with fast processing)
- ✅ Deploy-FromExcel-PS7.ps1 (PS7 deployment with fast processing)
- ✅ Manage-CertWebService-Updates.ps1 (Update management for ITSC020)
- ✅ Modules/ (FL-CredentialManager)
- ✅ Config/ (Configuration files)
- ✅ WebFiles/ (Web service files)

## CrossUse Integration:
- FL-FastServerProcessing.psm1 moved to CertSurv/Modules/
- Both CertWebService and CertSurv use shared performance module

## Next Steps:
1. Test deployment scripts
2. Verify CrossUse functionality
3. Run update management tool

Directory is now clean and optimized for production use.
"@

try {
    $summary | Out-File -FilePath $summaryPath -Encoding UTF8
    Write-Host ""
    Write-Host "📄 Cleanup summary saved: $summaryPath" -ForegroundColor Green
} catch {
    Write-Warning "Could not save cleanup summary: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "✅ CertWebService directory cleanup completed!" -ForegroundColor Green
Write-Host "🚀 Ready for production deployment from ITSC020 workstation" -ForegroundColor Green