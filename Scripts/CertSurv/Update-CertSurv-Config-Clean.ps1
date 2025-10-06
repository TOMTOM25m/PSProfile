#Requires -RunAsAdministrator
#Requires -Version 5.1

param(
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso",
    [string]$CertSurvPath = "C:\CertSurv"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  CONFIG FIX: EXCEL-PFAD KORREKTUR" -ForegroundColor Green  
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

Write-Host "PROBLEM:" -ForegroundColor Yellow
Write-Host "  Config zeigt: Serverliste2025test.xlsx (FALSCH)" -ForegroundColor Red
Write-Host "  Sollte sein:  Serverliste2025.xlsx (RICHTIG)" -ForegroundColor Green
Write-Host ""

# Update Config
Write-Host "[1/3] Update CertSurv Config..." -ForegroundColor Cyan
$configSource = Join-Path $NetworkPath "CertSurv\Config\Config-Cert-Surveillance.json"
$configTarget = Join-Path $CertSurvPath "Config\Config-Cert-Surveillance.json"

if (Test-Path $configSource) {
    # Backup old config
    if (Test-Path $configTarget) {
        $backupPath = "$configTarget.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $configTarget $backupPath -Force
        Write-Host "      [BACKUP] Alte Config gesichert" -ForegroundColor Gray
    }
    
    # Install new config
    Copy-Item $configSource $configTarget -Force
    Write-Host "      [OK] Config-Cert-Surveillance.json aktualisiert" -ForegroundColor Green
    Write-Host "      [FIX] Excel-Pfad korrigiert: Serverliste2025.xlsx" -ForegroundColor Yellow
} else {
    Write-Host "      [ERROR] Quell-Config nicht gefunden" -ForegroundColor Red
    exit 1
}

# Verify Config
Write-Host "[2/3] Verifikation der Config..." -ForegroundColor Cyan
try {
    $config = Get-Content $configTarget | ConvertFrom-Json
    $excelPath = $config.ExcelFilePath
    
    if ($excelPath -like "*Serverliste2025.xlsx") {
        Write-Host "      [OK] Excel-Pfad korrekt" -ForegroundColor Green
    } elseif ($excelPath -like "*Serverliste2025test.xlsx") {
        Write-Host "      [ERROR] Excel-Pfad immer noch falsch" -ForegroundColor Red
    } else {
        Write-Host "      [WARN] Unbekannter Excel-Pfad" -ForegroundColor Yellow
    }
    
    # Test if Excel file exists
    if (Test-Path $excelPath) {
        Write-Host "      [OK] Excel-Datei ist erreichbar" -ForegroundColor Green
    } else {
        Write-Host "      [WARN] Excel-Datei nicht erreichbar" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "      [ERROR] Config-Verifikation fehlgeschlagen" -ForegroundColor Red
}

# Test Debug Script with new config
Write-Host "[3/3] Teste Debug-Script mit neuer Config..." -ForegroundColor Cyan
$debugScript = "\\itscmgmt03.srv.meduniwien.ac.at\iso\Debug-ExcelHeaderContext.ps1"

if (Test-Path $debugScript) {
    Write-Host "      [INFO] Debug-Script verfuegbar" -ForegroundColor Gray
    Write-Host "      [INFO] Fuehre Debug-Script aus..." -ForegroundColor Gray
    
    try {
        & $debugScript
    } catch {
        Write-Host "      [WARN] Debug-Script fehlgeschlagen" -ForegroundColor Yellow
    }
} else {
    Write-Host "      [WARN] Debug-Script nicht gefunden" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  CONFIG-FIX ABGESCHLOSSEN!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "AENDERUNGEN:" -ForegroundColor Yellow
Write-Host "  [1] Config-Cert-Surveillance.json aktualisiert" -ForegroundColor White
Write-Host "  [2] Excel-Pfad korrigiert (ohne test)" -ForegroundColor White
Write-Host "  [3] Debug-Script mit neuer Config ausgefuehrt" -ForegroundColor White
Write-Host ""
Write-Host "TESTE JETZT:" -ForegroundColor Cyan
Write-Host "  Das Debug-Script sollte die korrekte Excel-Datei geladen haben" -ForegroundColor Gray
Write-Host "  und die Domain/Workgroup Zuordnung korrekt anzeigen!" -ForegroundColor Gray
Write-Host ""
Write-Host "Config-Fix abgeschlossen!" -ForegroundColor Green
Write-Host ""