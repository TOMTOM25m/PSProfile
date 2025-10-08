#Requires -Version 5.1

param(
    [string]$SourcePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    [string]$TargetPath = "C:\CertWebService",
    [int]$Port = 9080
)

Write-Host "=== CERTWEBSERVICE INSTALLER v2.5.0 ===" -ForegroundColor Green
Write-Host "Simple Network Share Installation" -ForegroundColor Gray
Write-Host ""

Write-Host "1. Quelle pruefen..." -ForegroundColor Cyan
if (-not (Test-Path $SourcePath)) {
    Write-Host "FEHLER: Network Share nicht erreichbar: $SourcePath" -ForegroundColor Red
    exit 1
}

$sourceFile = Join-Path $SourcePath "CertWebService.ps1"
if (-not (Test-Path $sourceFile)) {
    Write-Host "FEHLER: CertWebService.ps1 nicht gefunden" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Network Share verfuegbar" -ForegroundColor Green

Write-Host "2. Zielverzeichnis erstellen..." -ForegroundColor Cyan
try {
    if (-not (Test-Path $TargetPath)) {
        New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
        Write-Host "OK: Verzeichnis erstellt: $TargetPath" -ForegroundColor Green
    } else {
        Write-Host "OK: Verzeichnis existiert bereits" -ForegroundColor Green
    }
    
    $subDirs = @("Config", "Logs", "Reports")
    foreach ($dir in $subDirs) {
        $fullPath = Join-Path $TargetPath $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
        }
    }
} catch {
    Write-Host "FEHLER: Konnte Verzeichnis nicht erstellen" -ForegroundColor Red
    exit 1
}

Write-Host "3. Alte Version stoppen..." -ForegroundColor Cyan
try {
    $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*CertWebService*"
    }
    
    if ($processes) {
        $processes | Stop-Process -Force
        Write-Host "OK: Alte Prozesse gestoppt" -ForegroundColor Green
    } else {
        Write-Host "OK: Keine laufenden Prozesse gefunden" -ForegroundColor Green
    }
    
    Start-Sleep 2
} catch {
    Write-Host "WARNUNG: Konnte Prozesse nicht stoppen" -ForegroundColor Yellow
}

Write-Host "4. Dateien kopieren..." -ForegroundColor Cyan
try {
    $targetFile = Join-Path $TargetPath "CertWebService.ps1"
    Copy-Item $sourceFile $targetFile -Force
    Write-Host "OK: CertWebService.ps1 kopiert" -ForegroundColor Green
    
    $additionalFiles = @("Update.ps1", "Remove.ps1", "README.md")
    foreach ($file in $additionalFiles) {
        $sourcePath = Join-Path $SourcePath $file
        if (Test-Path $sourcePath) {
            $targetFilePath = Join-Path $TargetPath $file
            Copy-Item $sourcePath $targetFilePath -Force
            Write-Host "OK: $file kopiert" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "FEHLER: Kopieren fehlgeschlagen" -ForegroundColor Red
    exit 1
}

Write-Host "5. Service starten..." -ForegroundColor Cyan
try {
    Push-Location $TargetPath
    $startScript = {
        param($ServicePath, $ServicePort)
        Set-Location $ServicePath
        & powershell.exe -File "CertWebService.ps1" -Port $ServicePort
    }
    
    Start-Job -ScriptBlock $startScript -ArgumentList $TargetPath, $Port | Out-Null
    
    Write-Host "OK: Service gestartet auf Port $Port" -ForegroundColor Green
    Start-Sleep 5
    
    try {
        $result = Invoke-WebRequest "http://localhost:$Port/health.json" -TimeoutSec 10
        $health = $result.Content | ConvertFrom-Json
        Write-Host "OK: Service laeuft - Version $($health.version)" -ForegroundColor Green
    } catch {
        Write-Host "WARNUNG: Service-Test fehlgeschlagen" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "FEHLER: Service-Start fehlgeschlagen" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== INSTALLATION ABGESCHLOSSEN ===" -ForegroundColor Green
Write-Host "Dashboard: http://localhost:$Port/" -ForegroundColor Cyan
Write-Host "API: http://localhost:$Port/certificates.json" -ForegroundColor Cyan
Write-Host "Health: http://localhost:$Port/health.json" -ForegroundColor Cyan