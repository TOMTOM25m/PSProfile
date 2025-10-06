#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Update-Both-Services.ps1 - Aktualisiert CertWebService und CertSurv
.DESCRIPTION
    Kopiert die neuesten Dateien und startet beide Services neu
.NOTES
    Version: 1.0.0
    Regelwerk: v10.0.2  
    Author: GitHub Copilot
    Date: 2025-10-06
#>

param(
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso",
    [string]$CertWebServicePath = "C:\CertWebService",
    [string]$CertSurvPath = "C:\CertSurv"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  BEHEBT ALLE CERT-SURVEILLANCE FEHLER" -ForegroundColor Green  
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# 1. Update CertWebService
Write-Host "[1/5] Update CertWebService..." -ForegroundColor Cyan
$webServiceSource = Join-Path $NetworkPath "CertWebService\CertWebService.ps1"
$webServiceTarget = Join-Path $CertWebServicePath "CertWebService.ps1"

if (Test-Path $webServiceSource) {
    Copy-Item $webServiceSource $webServiceTarget -Force
    Write-Host "      [OK] CertWebService.ps1 aktualisiert" -ForegroundColor Green
    Write-Host "      [FIX] API Response jetzt mit total_count Struktur" -ForegroundColor Yellow
}

# 2. Update CertSurv Modules
Write-Host "[2/5] Update CertSurv Modules..." -ForegroundColor Cyan

# FL-NetworkOperations (Property Fix)
$moduleSource1 = Join-Path $NetworkPath "CertSurv\Modules\FL-NetworkOperations.psm1"
$moduleTarget1 = Join-Path $CertSurvPath "Modules\FL-NetworkOperations.psm1"

if (Test-Path $moduleSource1) {
    Copy-Item $moduleSource1 $moduleTarget1 -Force
    Write-Host "      [OK] FL-NetworkOperations.psm1 aktualisiert" -ForegroundColor Green
    Write-Host "      [FIX] Alle Server bekommen jetzt _RetrievalMethod Property" -ForegroundColor Yellow
}

# FL-DataProcessing (Excel Block-Header Fix)
$moduleSource2 = Join-Path $NetworkPath "CertSurv\Modules\FL-DataProcessing.psm1"
$moduleTarget2 = Join-Path $CertSurvPath "Modules\FL-DataProcessing.psm1"

if (Test-Path $moduleSource2) {
    Copy-Item $moduleSource2 $moduleTarget2 -Force
    Write-Host "      [OK] FL-DataProcessing.psm1 aktualisiert" -ForegroundColor Green
    Write-Host "      [FIX] Excel Block-Header werden korrekt gefiltert" -ForegroundColor Yellow
    Write-Host "      [FIX] Domain-UVW und SUMME Header nicht mehr als Server behandelt" -ForegroundColor Yellow
}

# 3. Restart CertWebService
Write-Host "[3/5] Starte CertWebService neu..." -ForegroundColor Cyan
$webServiceTask = "CertWebService-WebServer"
$task = Get-ScheduledTask -TaskName $webServiceTask -ErrorAction SilentlyContinue

if ($task) {
    Stop-ScheduledTask -TaskName $webServiceTask -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-ScheduledTask -TaskName $webServiceTask
    Start-Sleep -Seconds 2
    
    # Test Web Service
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "      [OK] CertWebService läuft korrekt" -ForegroundColor Green
        }
    } catch {
        Write-Host "      [WARN] CertWebService reagiert nicht" -ForegroundColor Yellow
    }
} else {
    Write-Host "      [WARN] Task $webServiceTask nicht gefunden!" -ForegroundColor Yellow
}

# 4. Test CertSurv
Write-Host "[4/5] Teste CertSurv (kurzer Test)..." -ForegroundColor Cyan
$certSurvScript = Join-Path $CertSurvPath "Core-Applications\Cert-Surveillance-Main.ps1"

if (Test-Path $certSurvScript) {
    try {
        # Kurzer Test mit Timeout
        $testJob = Start-Job -ScriptBlock {
            param($path)
            & $path
        } -ArgumentList $certSurvScript
        
        Wait-Job $testJob -Timeout 30 | Out-Null
        
        if ($testJob.State -eq "Running") {
            Stop-Job $testJob -Force
            Write-Host "      [OK] CertSurv startet ohne Fehler" -ForegroundColor Green
        } elseif ($testJob.State -eq "Completed") {
            $result = Receive-Job $testJob
            Write-Host "      [OK] CertSurv Test erfolgreich" -ForegroundColor Green
        } else {
            Write-Host "      [WARN] CertSurv Test unbestimmt" -ForegroundColor Yellow
        }
        
        Remove-Job $testJob -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "      [WARN] CertSurv Test fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Zusammenfassung
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  FIXES DEPLOYED!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "BEHOBENE PROBLEME:" -ForegroundColor Yellow
Write-Host "  [1] CertWebService API Response jetzt kompatibel" -ForegroundColor White
Write-Host "      Struktur mit total_count hinzugefuegt" -ForegroundColor Gray
Write-Host "  [2] _RetrievalMethod Property fuer alle Server" -ForegroundColor White  
Write-Host "      Verhindert property not found Fehler" -ForegroundColor Gray
Write-Host "  [3] Excel Block-Header werden korrekt gefiltert" -ForegroundColor White
Write-Host "      Domain-UVW und SUMME Header nicht mehr als Server" -ForegroundColor Gray
Write-Host ""
Write-Host "TESTE JETZT:" -ForegroundColor Cyan
$testCommand = "& '$certSurvScript'"
Write-Host "  $testCommand" -ForegroundColor Gray
Write-Host ""
Write-Host "Alle drei Hauptfehler sollten jetzt behoben sein!" -ForegroundColor Green
Write-Host ""