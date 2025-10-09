#requires -version 5.1

<#
.SYNOPSIS
    Fix Encoding Issues in CertWebService Files

.DESCRIPTION
    Konvertiert alle PS1/PSM1/JSON Dateien korrekt:
    - PowerShell 5.1: ASCII
    - PowerShell 7+: UTF-8 mit BOM
    
.AUTHOR
    Flecki (Tom) Garnreiter

.VERSION
    1.0.1

.RULEBOOK
    v10.0.3
#>

$ErrorActionPreference = 'Stop'

# PowerShell Version Detection (Regelwerk v10.0.3 compliant)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Fix Encoding - CertWebService" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$TargetPath = "C:\CertWebService"
$BackupPath = "C:\CertWebService\Backup\Encoding-Fix-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Check if running on correct server
if ($env:COMPUTERNAME -notlike "*ITSCMGMT03*") {
    Write-Host "[WARNING] This script should run on ITSCMGMT03!" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne 'y') { exit }
}

# Create backup directory
Write-Host "[Step 1] Creating backup..." -ForegroundColor Yellow
if (-not (Test-Path $BackupPath)) {
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
}

# Find all script files
$Files = Get-ChildItem -Path $TargetPath -Include "*.ps1", "*.psm1", "*.json" -Recurse -File | 
    Where-Object { $_.FullName -notlike "*\Backup\*" -and $_.FullName -notlike "*\Logs\*" }

Write-Host "Found $($Files.Count) files to process`n" -ForegroundColor White

$ProcessedCount = 0
$ErrorCount = 0

foreach ($file in $Files) {
    try {
        Write-Host "Processing: $($file.Name)" -ForegroundColor Gray
        
        # Backup original
        $relativePath = $file.FullName.Replace($TargetPath, "").TrimStart('\')
        $backupFile = Join-Path $BackupPath $relativePath
        $backupDir = Split-Path $backupFile -Parent
        
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }
        
        Copy-Item -Path $file.FullName -Destination $backupFile -Force
        
        # Read content - REGELWERK v10.0.3 compliant
        if ($IsPS7Plus) {
            # PowerShell 7+: Use UTF-8 with BOM
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        } else {
            # PowerShell 5.1: Use Default (ASCII-compatible)
            $content = Get-Content -Path $file.FullName -Raw
        }
        
        # Fix common encoding issues using hex codes
        $content = $content -replace ([char]0xC3 + [char]0xA4), 'ä'  # ä (UTF-8: C3 A4)
        $content = $content -replace ([char]0xC3 + [char]0xB6), 'ö'  # ö (UTF-8: C3 B6)
        $content = $content -replace ([char]0xC3 + [char]0xBC), 'ü'  # ü (UTF-8: C3 BC)
        $content = $content -replace ([char]0xC3 + [char]0x84), 'Ä'  # Ä (UTF-8: C3 84)
        $content = $content -replace ([char]0xC3 + [char]0x96), 'Ö'  # Ö (UTF-8: C3 96)
        $content = $content -replace ([char]0xC3 + [char]0x9C), 'Ü'  # Ü (UTF-8: C3 9C)
        $content = $content -replace ([char]0xC3 + [char]0x9F), 'ß'  # ß (UTF-8: C3 9F)
        
        # Write with correct encoding - REGELWERK v10.0.3 compliant
        if ($IsPS7Plus) {
            # PowerShell 7+: UTF-8 with BOM
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($file.FullName, $content, $utf8WithBom)
            Write-Host "  [OK] Fixed encoding (UTF-8 with BOM)" -ForegroundColor Green
        } else {
            # PowerShell 5.1: ASCII
            $content | Out-File -FilePath $file.FullName -Encoding ASCII -Force -NoNewline
            Write-Host "  [OK] Fixed encoding (ASCII)" -ForegroundColor Green
        }
        
        $ProcessedCount++
        
    } catch {
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        $ErrorCount++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Files: $($Files.Count)" -ForegroundColor White
Write-Host "Processed: $ProcessedCount" -ForegroundColor $(if ($ProcessedCount -eq $Files.Count) { 'Green' } else { 'Yellow' })
Write-Host "Errors: $ErrorCount" -ForegroundColor $(if ($ErrorCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "Backup: $BackupPath" -ForegroundColor White
Write-Host "`n[SUCCESS] Encoding fix complete!`n" -ForegroundColor Green

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Restart CertWebService" -ForegroundColor White
Write-Host "2. Check Dashboard: http://localhost:9080/" -ForegroundColor White
Write-Host "3. Verify German characters are displayed correctly`n" -ForegroundColor White
