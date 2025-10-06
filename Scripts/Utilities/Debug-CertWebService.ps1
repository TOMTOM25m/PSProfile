# CertWebService Debug & Fix Script
# Debuggt und repariert Web-Service Probleme
# Version: v1.1.0 | Stand: 02.10.2025

Write-Host "=== CERTWEBSERVICE DEBUG & FIX ===" -ForegroundColor Magenta
Write-Host "Debugging Web-Service Probleme..." -ForegroundColor Yellow
Write-Host ""

# 1. Prüfe Scheduled Tasks
Write-Host "1. SCHEDULED TASKS STATUS:" -ForegroundColor Cyan
Get-ScheduledTask -TaskName "CertWebService*" | Select-Object TaskName, State | Format-Table -AutoSize

# 2. Prüfe ob PowerShell-Prozess läuft
Write-Host "2. POWERSHELL PROZESSE (CertWebService):" -ForegroundColor Cyan
$processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { 
    $_.CommandLine -like "*CertWebService*" -or $_.MainWindowTitle -like "*CertWebService*"
}
if ($processes) {
    $processes | Select-Object Id, ProcessName, CPU, WorkingSet | Format-Table -AutoSize
} else {
    Write-Host "❌ Keine CertWebService PowerShell-Prozesse gefunden!" -ForegroundColor Red
}

# 3. Prüfe Port 9080
Write-Host "3. PORT 9080 STATUS:" -ForegroundColor Cyan
try {
    $netstat = netstat -an | findstr :9080
    if ($netstat) {
        Write-Host "✅ Port 9080 wird verwendet:" -ForegroundColor Green
        Write-Host $netstat -ForegroundColor Gray
    } else {
        Write-Host "❌ Port 9080 ist NICHT belegt!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Fehler bei Port-Prüfung: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Prüfe CertWebService.ps1 direkt
Write-Host "4. CERTWEBSERVICE.PS1 TEST:" -ForegroundColor Cyan
$webServiceScript = "C:\CertWebService\CertWebService.ps1"
if (Test-Path $webServiceScript) {
    Write-Host "✅ CertWebService.ps1 gefunden" -ForegroundColor Green
    Write-Host "Teste direkten Start..." -ForegroundColor Yellow
    
    # Teste manuellen Start
    try {
        Write-Host "Starte Web-Service manuell (10 Sekunden Test)..." -ForegroundColor Yellow
        $job = Start-Job -ScriptBlock {
            param($scriptPath)
            & $scriptPath
        } -ArgumentList $webServiceScript
        
        Start-Sleep -Seconds 3
        
        # Teste Verbindung
        try {
            $response = Invoke-WebRequest "http://localhost:9080/" -UseBasicParsing -TimeoutSec 5
            Write-Host "✅ Web-Service läuft! Status: $($response.StatusCode)" -ForegroundColor Green
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "❌ Web-Service nicht erreichbar: $($_.Exception.Message)" -ForegroundColor Red
            
            # Zeige Job-Output für Debugging
            $jobOutput = Receive-Job $job -ErrorAction SilentlyContinue
            if ($jobOutput) {
                Write-Host "Job Output:" -ForegroundColor Yellow
                Write-Host $jobOutput -ForegroundColor Gray
            }
            
            Stop-Job $job -ErrorAction SilentlyContinue  
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }
        
    } catch {
        Write-Host "❌ Fehler beim manuellen Start: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ CertWebService.ps1 nicht gefunden!" -ForegroundColor Red
}

# 5. Prüfe Logs
Write-Host "5. LOG-ANALYSE:" -ForegroundColor Cyan
$logDir = "C:\CertWebService\Logs"
if (Test-Path $logDir) {
    $logFiles = Get-ChildItem $logDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if ($logFiles) {
        Write-Host "Letzte Log-Dateien:" -ForegroundColor Yellow
        foreach ($log in $logFiles) {
            Write-Host "📄 $($log.Name) - $($log.LastWriteTime)" -ForegroundColor Gray
            Write-Host "Letzte 5 Zeilen:" -ForegroundColor Yellow
            Get-Content $log.FullName | Select-Object -Last 5 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
            Write-Host ""
        }
    } else {
        Write-Host "❌ Keine Log-Dateien gefunden!" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Log-Verzeichnis nicht gefunden!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== FIX SUGGESTIONS ===" -ForegroundColor Yellow
Write-Host "1. Scheduled Task manuell starten:" -ForegroundColor White
Write-Host "   Start-ScheduledTask -TaskName 'CertWebService-WebServer'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Web-Service direkt testen:" -ForegroundColor White  
Write-Host "   & 'C:\CertWebService\CertWebService.ps1'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Task neu erstellen:" -ForegroundColor White
Write-Host "   .\Setup.ps1" -ForegroundColor Gray