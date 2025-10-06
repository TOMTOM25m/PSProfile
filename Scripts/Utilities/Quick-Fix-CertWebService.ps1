# CertWebService Quick Fix
# Repariert und startet Web-Service sofort
# Version: v1.1.0 | Stand: 02.10.2025

Write-Host "=== CERTWEBSERVICE QUICK FIX ===" -ForegroundColor Magenta
Write-Host "Repariere Web-Service..." -ForegroundColor Yellow
Write-Host ""

# 1. Stoppe alle Tasks
Write-Host "1. Stoppe bestehende Tasks..." -ForegroundColor Cyan
try {
    Stop-ScheduledTask -TaskName "CertWebService-WebServer" -ErrorAction SilentlyContinue
    Write-Host "✅ Web-Server Task gestoppt" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Web-Server Task war bereits gestoppt" -ForegroundColor Yellow
}

# 2. Prüfe ob Port frei ist
Write-Host "2. Prüfe Port 9080..." -ForegroundColor Cyan
$portInUse = netstat -an | findstr :9080
if ($portInUse) {
    Write-Host "⚠️  Port 9080 wird verwendet:" -ForegroundColor Yellow
    Write-Host $portInUse -ForegroundColor Gray
} else {
    Write-Host "✅ Port 9080 ist frei" -ForegroundColor Green
}

# 3. Starte Web-Service direkt (nicht als Task)
Write-Host "3. Starte Web-Service direkt..." -ForegroundColor Cyan
$webServiceScript = "C:\CertWebService\CertWebService.ps1"

if (Test-Path $webServiceScript) {
    Write-Host "Starte CertWebService.ps1 im Hintergrund..." -ForegroundColor Yellow
    
    # Starte als Background-Job
    $job = Start-Job -Name "CertWebService-Direct" -ScriptBlock {
        param($scriptPath)
        try {
            Set-Location "C:\CertWebService"
            & $scriptPath
        } catch {
            Write-Error "Fehler beim Start: $($_.Exception.Message)"
        }
    } -ArgumentList $webServiceScript
    
    Write-Host "✅ Web-Service Job gestartet (ID: $($job.Id))" -ForegroundColor Green
    
    # Warte kurz und teste
    Write-Host "Warte 5 Sekunden..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    
    # Teste Verbindung
    Write-Host "4. Teste Verbindung..." -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest "http://localhost:9080/" -UseBasicParsing -TimeoutSec 10
        Write-Host "🎉 SUCCESS! Web-Service läuft!" -ForegroundColor Green
        Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "URL: http://localhost:9080" -ForegroundColor Cyan
        
        # Zeige Job-Status
        $jobInfo = Get-Job -Id $job.Id
        Write-Host "Job Status: $($jobInfo.State)" -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ Web-Service noch nicht erreichbar: $($_.Exception.Message)" -ForegroundColor Red
        
        # Zeige Job-Output
        Write-Host "Job Output:" -ForegroundColor Yellow
        $output = Receive-Job $job -ErrorAction SilentlyContinue
        if ($output) {
            $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        } else {
            Write-Host "  (Kein Output verfügbar)" -ForegroundColor Gray
        }
    }
    
} else {
    Write-Host "❌ CertWebService.ps1 nicht gefunden: $webServiceScript" -ForegroundColor Red
    Write-Host "Verfügbare Dateien:" -ForegroundColor Yellow
    Get-ChildItem "C:\CertWebService" -Filter "*.ps1" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
}

Write-Host ""
Write-Host "=== NÄCHSTE SCHRITTE ===" -ForegroundColor Yellow
Write-Host "1. Browser öffnen: http://localhost:9080" -ForegroundColor White
Write-Host "2. Job-Status prüfen: Get-Job" -ForegroundColor White
Write-Host "3. Job-Output anzeigen: Receive-Job -Name 'CertWebService-Direct'" -ForegroundColor White
Write-Host "4. Job stoppen: Stop-Job -Name 'CertWebService-Direct'" -ForegroundColor White

Write-Host ""
Write-Host "💡 HINWEIS: Dieser Start umgeht die Scheduled Tasks und startet direkt!" -ForegroundColor Cyan