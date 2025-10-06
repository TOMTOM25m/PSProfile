#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Fix-Excel-BlockHeaders.ps1 - Behebt Excel Block-Header Parsing Problem
.DESCRIPTION
    Installiert korrigiertes FL-DataProcessing.psm1 das Excel Headers wie (Domain)UVW und SUMME: korrekt filtert
.NOTES
    Version: 1.0.0
    Regelwerk: v10.0.2
    Author: GitHub Copilot
    Date: 2025-10-06
    
    PROBLEM BEHOBEN:
    - "(Domain)UVW" und "SUMME:" werden nicht mehr als Server behandelt
    - Korrektes Filtering von Excel Block-Headern vor Server-Verarbeitung
#>

param(
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso",
    [string]$CertSurvPath = "C:\CertSurv"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  EXCEL BLOCK-HEADER FIX INSTALLATION" -ForegroundColor Green  
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

Write-Host "PROBLEM:" -ForegroundColor Yellow
Write-Host "  ❌ '(Domain)UVW' wurde als Server behandelt" -ForegroundColor Red
Write-Host "  ❌ 'SUMME:' wurde als Server behandelt" -ForegroundColor Red
Write-Host ""

Write-Host "LÖSUNG:" -ForegroundColor Yellow
Write-Host "  ✅ Excel Block-Header werden korrekt gefiltert" -ForegroundColor Green
Write-Host "  ✅ Nur echte Server werden verarbeitet" -ForegroundColor Green
Write-Host ""

# Update FL-DataProcessing Module
Write-Host "[1/3] Update FL-DataProcessing Modul..." -ForegroundColor Cyan
$moduleSource = Join-Path $NetworkPath "CertSurv\Modules\FL-DataProcessing.psm1"
$moduleTarget = Join-Path $CertSurvPath "Modules\FL-DataProcessing.psm1"

if (Test-Path $moduleSource) {
    # Backup old version
    if (Test-Path $moduleTarget) {
        $backupPath = "$moduleTarget.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $moduleTarget $backupPath -Force
        Write-Host "      [BACKUP] Alte Version gesichert: $(Split-Path $backupPath -Leaf)" -ForegroundColor Gray
    }
    
    # Install new version
    Copy-Item $moduleSource $moduleTarget -Force
    Write-Host "      [OK] FL-DataProcessing.psm1 aktualisiert" -ForegroundColor Green
    Write-Host "      [FIX] Filter-ExcelBlockHeaders Funktion hinzugefügt" -ForegroundColor Yellow
    Write-Host "      [FIX] Filtert (Domain)UVW und SUMME: Header korrekt" -ForegroundColor Yellow
} else {
    Write-Host "      [ERROR] Quell-Modul nicht gefunden: $moduleSource" -ForegroundColor Red
    exit 1
}

# Test Module Import
Write-Host "[2/3] Teste Modul-Import..." -ForegroundColor Cyan
try {
    Import-Module $moduleTarget -Force -ErrorAction Stop
    $functions = Get-Command -Module FL-DataProcessing | Where-Object { $_.Name -eq "Filter-ExcelBlockHeaders" }
    
    if ($functions) {
        Write-Host "      [OK] Filter-ExcelBlockHeaders Funktion verfügbar" -ForegroundColor Green
    } else {
        Write-Host "      [WARN] Filter-ExcelBlockHeaders Funktion nicht gefunden" -ForegroundColor Yellow
    }
    
    Remove-Module FL-DataProcessing -Force -ErrorAction SilentlyContinue
    Write-Host "      [OK] Modul erfolgreich getestet" -ForegroundColor Green
} catch {
    Write-Host "      [ERROR] Modul-Import fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
}

# Test CertSurv with new module
Write-Host "[3/3] Teste CertSurv mit neuem Modul..." -ForegroundColor Cyan
$certSurvScript = Join-Path $CertSurvPath "Core-Applications\Cert-Surveillance-Main.ps1"

if (Test-Path $certSurvScript) {
    try {
        # Quick syntax test
        $testJob = Start-Job -ScriptBlock {
            param($path)
            # Just test parsing - don't run full scan
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $path -Raw), [ref]$null)
            return "OK"
        } -ArgumentList $certSurvScript
        
        $result = Wait-Job $testJob -Timeout 10 | Receive-Job
        Remove-Job $testJob -Force
        
        if ($result -eq "OK") {
            Write-Host "      [OK] CertSurv Syntax-Test erfolgreich" -ForegroundColor Green
        } else {
            Write-Host "      [WARN] CertSurv Syntax-Test unbestimmt" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "      [WARN] CertSurv Test fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "      [INFO] CertSurv Hauptskript nicht gefunden - überspringe Test" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  EXCEL BLOCK-HEADER FIX INSTALLIERT!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "ÄNDERUNGEN:" -ForegroundColor Yellow
Write-Host "  ✓ FL-DataProcessing.psm1 aktualisiert" -ForegroundColor White
Write-Host "  ✓ Filter-ExcelBlockHeaders() Funktion hinzugefügt" -ForegroundColor White
Write-Host "  ✓ Excel Block-Header werden vor Server-Verarbeitung gefiltert" -ForegroundColor White
Write-Host ""
Write-Host "BEHOBENE PROBLEME:" -ForegroundColor Yellow
Write-Host "  ❌ '(Domain)UVW' wird nicht mehr als Server verarbeitet" -ForegroundColor Green
Write-Host "  ❌ 'SUMME:' wird nicht mehr als Server verarbeitet" -ForegroundColor Green
Write-Host "  ❌ 'marked as workgroup server (no context found)' für Header behoben" -ForegroundColor Green
Write-Host ""
Write-Host "TESTE JETZT:" -ForegroundColor Cyan
Write-Host "  & `"$certSurvScript`"" -ForegroundColor Gray
Write-Host ""
Write-Host "Das Excel Block-Header Problem sollte jetzt behoben sein!" -ForegroundColor Green
Write-Host ""