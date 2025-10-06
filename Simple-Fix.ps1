# CertWebService Simple Fix - ASCII Only
# Version: v1.1.3 | Stand: 02.10.2025

Write-Host "=== CERTWEBSERVICE SIMPLE FIX ===" -ForegroundColor White
Write-Host "Regelwerk v10.0.2" -ForegroundColor Gray
Write-Host ""

# 1. Stoppe Tasks
Write-Host "1. Stoppe Tasks..." -ForegroundColor Yellow
Stop-ScheduledTask -TaskName "CertWebService-WebServer" -ErrorAction SilentlyContinue
Write-Host "   Tasks gestoppt" -ForegroundColor Green

# 2. Pruefe Port
Write-Host "2. Pruefe Port 9080..." -ForegroundColor Yellow
$portCheck = netstat -an | findstr ":9080"
if ($portCheck) {
    Write-Host "   Port belegt: $portCheck" -ForegroundColor Red
} else {
    Write-Host "   Port frei" -ForegroundColor Green
}

# 3. Pruefe CertWebService.ps1
Write-Host "3. Pruefe Script..." -ForegroundColor Yellow
$script1 = "C:\CertWebService\CertWebService.ps1"
$script2 = "C:\CertWebService\ScanCertificates.ps1"

if (Test-Path $script1) {
    Write-Host "   Gefunden: CertWebService.ps1" -ForegroundColor Green
    $scriptToRun = $script1
} elseif (Test-Path $script2) {
    Write-Host "   Gefunden: ScanCertificates.ps1" -ForegroundColor Green  
    $scriptToRun = $script2
} else {
    Write-Host "   FEHLER: Kein Script gefunden!" -ForegroundColor Red
    Write-Host "   Verfuegbare Dateien:" -ForegroundColor Yellow
    Get-ChildItem "C:\CertWebService" -Filter "*.ps1" | ForEach-Object {
        Write-Host "     $($_.Name)" -ForegroundColor Gray
    }
    exit 1
}

# 4. Starte Script direkt
Write-Host "4. Starte Script..." -ForegroundColor Yellow
try {
    # Direkter Start ohne Job (einfacher)
    Write-Host "   Starte: $scriptToRun" -ForegroundColor Gray
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass", "-File `"$scriptToRun`"" -WindowStyle Hidden
    Write-Host "   Prozess gestartet" -ForegroundColor Green
} catch {
    Write-Host "   FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5. Warten und testen
Write-Host "5. Teste Verbindung..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

for ($i = 1; $i -le 3; $i++) {
    try {
        $response = Invoke-WebRequest "http://localhost:9080/" -UseBasicParsing -TimeoutSec 5
        Write-Host "   SUCCESS! Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "   URL: http://localhost:9080" -ForegroundColor Cyan
        break
    } catch {
        Write-Host "   Versuch $i fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        if ($i -lt 3) {
            Start-Sleep -Seconds 5
        }
    }
}

Write-Host ""
Write-Host "=== FERTIG ===" -ForegroundColor White
Write-Host "Browser: http://localhost:9080" -ForegroundColor Cyan
Write-Host "Prozesse: Get-Process powershell" -ForegroundColor Gray