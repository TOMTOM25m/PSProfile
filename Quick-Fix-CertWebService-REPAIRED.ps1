# CertWebService Quick Fix - REPAIRED
# Repariert und startet Web-Service sofort
# Version: v1.1.1 | Stand: 02.10.2025

Write-Host "=== CERTWEBSERVICE QUICK FIX (REPAIRED) ===" -ForegroundColor Magenta
Write-Host "Repariere Web-Service..." -ForegroundColor Yellow
Write-Host ""

# 1. Stoppe alle Tasks
Write-Host "1. Stoppe bestehende Tasks..." -ForegroundColor Cyan
try {
    Stop-ScheduledTask -TaskName "CertWebService-WebServer" -ErrorAction SilentlyContinue
    Write-Host "OK - Web-Server Task gestoppt" -ForegroundColor Green
} catch {
    Write-Host "OK - Web-Server Task war bereits gestoppt" -ForegroundColor Yellow
}

# 2. Prüfe ob Port frei ist
Write-Host "2. Prüfe Port 9080..." -ForegroundColor Cyan
$portCheck = netstat -an | findstr ":9080"
if ($portCheck) {
    Write-Host "WARNUNG - Port 9080 wird verwendet:" -ForegroundColor Yellow
    Write-Host $portCheck -ForegroundColor Gray
} else {
    Write-Host "OK - Port 9080 ist frei" -ForegroundColor Green
}

# 3. Starte Web-Service direkt
Write-Host "3. Starte Web-Service direkt..." -ForegroundColor Cyan
$webServiceScript = "C:\CertWebService\CertWebService.ps1"

if (Test-Path $webServiceScript) {
    Write-Host "Starte CertWebService.ps1 im Hintergrund..." -ForegroundColor Yellow
    
    # Starte als Background-Job (ohne komplexe ScriptBlocks)
    $jobCommand = "Set-Location 'C:\CertWebService'; & '$webServiceScript'"
    $job = Start-Job -Name "CertWebService-Direct" -ScriptBlock ([scriptblock]::Create($jobCommand))
    
    Write-Host "OK - Web-Service Job gestartet (ID: $($job.Id))" -ForegroundColor Green
    
    # Warte und teste
    Write-Host "Warte 8 Sekunden auf Start..." -ForegroundColor Gray
    Start-Sleep -Seconds 8
    
    # Teste Verbindung
    Write-Host "4. Teste Verbindung..." -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest "http://localhost:9080/" -UseBasicParsing -TimeoutSec 15
        Write-Host "SUCCESS! Web-Service laeuft!" -ForegroundColor Green
        Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "URL: http://localhost:9080" -ForegroundColor Cyan
        
    } catch {
        Write-Host "FEHLER - Web-Service nicht erreichbar:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        
        # Zeige Job-Output
        Write-Host "Job Output:" -ForegroundColor Yellow
        $output = Receive-Job $job -ErrorAction SilentlyContinue
        if ($output) {
            $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
    }
    
} else {
    Write-Host "FEHLER - CertWebService.ps1 nicht gefunden!" -ForegroundColor Red
    Write-Host "Gesucht: $webServiceScript" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== NAECHSTE SCHRITTE ===" -ForegroundColor Yellow
Write-Host "1. Browser: http://localhost:9080" -ForegroundColor White
Write-Host "2. Job Status: Get-Job" -ForegroundColor White
Write-Host "3. Job Output: Receive-Job -Name CertWebService-Direct" -ForegroundColor White