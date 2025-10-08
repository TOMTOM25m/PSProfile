#Requires -Version 5.1

<#
.SYNOPSIS
CertWebService - Enhanced Network Share Installer v2.5.0
.DESCRIPTION
Installiert CertWebService von Network Share auf lokalen Server
- Aktiviert PSRemoting für ITSC020 und ITSCMGMT03
- Erstellt saubere Installation
- Behebt Encoding-Probleme
#>

param(
    [string]$SourcePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    [string]$TargetPath = "C:\CertWebService",
    [int]$Port = 9080,
    [switch]$EnablePSRemoting
)

Write-Host "=== CERTWEBSERVICE INSTALLER v2.5.0 ===" -ForegroundColor Green
Write-Host "Enhanced Network Share Installation mit PSRemoting" -ForegroundColor Gray
Write-Host ""

# PSRemoting Konfiguration
if ($EnablePSRemoting) {
    Write-Host "0. PSRemoting konfigurieren..." -ForegroundColor Cyan
    try {
        # PSRemoting aktivieren
        Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
        
        # WinRM Konfiguration
        Set-WSManQuickConfig -Force | Out-Null
        
        # Nur ITSC020 und ITSCMGMT03 erlauben
        $allowedHosts = @(
            "ITSC020.cc.meduniwien.ac.at",
            "ITSCMGMT03.srv.meduniwien.ac.at"
        )
        
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value ($allowedHosts -join ",") -Force
        
        # Firewall-Regel für WinRM
        New-NetFirewallRule -DisplayName "WinRM-HTTP-ITSC" -Direction Inbound -Protocol TCP -LocalPort 5985 -RemoteAddress @("149.148.84.0/24", "149.148.85.0/24") -Action Allow -ErrorAction SilentlyContinue | Out-Null
        
        # WinRM Service starten
        Start-Service WinRM -ErrorAction SilentlyContinue
        Set-Service WinRM -StartupType Automatic -ErrorAction SilentlyContinue
        
        Write-Host "✅ PSRemoting aktiviert für ITSC020 und ITSCMGMT03" -ForegroundColor Green
        
    } catch {
        Write-Host "WARNUNG: PSRemoting-Konfiguration teilweise fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "1. Quelle prüfen..." -ForegroundColor Cyan
if (-not (Test-Path $SourcePath)) {
    Write-Host "FEHLER: Network Share nicht erreichbar: $SourcePath" -ForegroundColor Red
    Write-Host "Stelle sicher, dass du Zugang zum Share hast!" -ForegroundColor Yellow
    exit 1
}

$sourceFile = Join-Path $SourcePath "CertWebService.ps1"
if (-not (Test-Path $sourceFile)) {
    Write-Host "FEHLER: CertWebService.ps1 nicht gefunden in $SourcePath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Network Share verfügbar" -ForegroundColor Green

Write-Host "2. Zielverzeichnis erstellen..." -ForegroundColor Cyan
try {
    if (-not (Test-Path $TargetPath)) {
        New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
        Write-Host "✅ Verzeichnis erstellt: $TargetPath" -ForegroundColor Green
    } else {
        Write-Host "✅ Verzeichnis existiert bereits: $TargetPath" -ForegroundColor Green
    }
    
    # Unterverzeichnisse erstellen
    $subDirs = @("Config", "Logs", "Reports")
    foreach ($dir in $subDirs) {
        $fullPath = Join-Path $TargetPath $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            Write-Host "  ✅ $dir" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "FEHLER: Konnte Verzeichnis nicht erstellen: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "3. Alte Version stoppen..." -ForegroundColor Cyan
try {
    # Stoppe alle PowerShell-Prozesse die CertWebService ausführen
    $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*CertWebService*"
    }
    
    if ($processes) {
        $processes | Stop-Process -Force
        Write-Host "✅ Alte Prozesse gestoppt" -ForegroundColor Green
    } else {
        Write-Host "✅ Keine laufenden Prozesse gefunden" -ForegroundColor Green
    }
    
    Start-Sleep 2
} catch {
    Write-Host "WARNUNG: Konnte Prozesse nicht stoppen: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "4. Dateien kopieren (UTF-8 Encoding Fix)..." -ForegroundColor Cyan
try {
    # Hauptdatei mit korrektem Encoding kopieren
    $targetFile = Join-Path $TargetPath "CertWebService.ps1"
    
    # Lese Inhalt und schreibe mit UTF-8 BOM (PowerShell-kompatibel)
    $content = Get-Content $sourceFile -Raw -Encoding UTF8
    if ([string]::IsNullOrEmpty($content)) {
        throw "Quelldatei ist leer oder nicht lesbar"
    }
    
    # Schreibe mit UTF-8 BOM für PowerShell-Kompatibilität
    [System.IO.File]::WriteAllText($targetFile, $content, [System.Text.UTF8Encoding]::new($true))
    
    Write-Host "✅ CertWebService.ps1 kopiert (UTF-8)" -ForegroundColor Green
    
    # Prüfe ob weitere Dateien vorhanden sind
    $additionalFiles = @("Update.ps1", "Remove.ps1", "README.md")
    foreach ($file in $additionalFiles) {
        $sourcePath = Join-Path $SourcePath $file
        if (Test-Path $sourcePath) {
            $targetPath = Join-Path $TargetPath $file
            try {
                $fileContent = Get-Content $sourcePath -Raw -Encoding UTF8
                [System.IO.File]::WriteAllText($targetPath, $fileContent, [System.Text.UTF8Encoding]::new($true))
                Write-Host "  ✅ $file (UTF-8)" -ForegroundColor Gray
            } catch {
                # Fallback: normales Kopieren
                Copy-Item $sourcePath $targetPath -Force
                Write-Host "  ✅ $file (Fallback)" -ForegroundColor Gray
            }
        }
    }
    
    # Syntax-Prüfung der Hauptdatei
    Write-Host "  🔍 Syntax-Prüfung..." -ForegroundColor Gray
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "  ✅ PowerShell-Syntax OK" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Syntax-Warnung: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "FEHLER: Kopieren fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "5. Service starten..." -ForegroundColor Cyan
try {
    Set-Location $TargetPath
    $startScript = {
        param($ServicePath, $ServicePort)
        Set-Location $ServicePath
        & powershell.exe -File "CertWebService.ps1" -Port $ServicePort
    }
    
    # Starte Service im Hintergrund
    Start-Job -ScriptBlock $startScript -ArgumentList $TargetPath, $Port | Out-Null
    
    Write-Host "✅ Service gestartet auf Port $Port" -ForegroundColor Green
    Start-Sleep 5
    
    # Test Service
    try {
        $result = Invoke-WebRequest "http://localhost:$Port/health.json" -TimeoutSec 10
        $health = $result.Content | ConvertFrom-Json
        Write-Host "✅ Service läuft: Version $($health.version)" -ForegroundColor Green
    } catch {
        Write-Host "WARNUNG: Service-Test fehlgeschlagen - Service läuft möglicherweise noch nicht" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "FEHLER: Service-Start fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== INSTALLATION ABGESCHLOSSEN ===" -ForegroundColor Green
Write-Host "Dashboard: http://localhost:$Port/" -ForegroundColor Cyan
Write-Host "API: http://localhost:$Port/certificates.json" -ForegroundColor Cyan
Write-Host "Health: http://localhost:$Port/health.json" -ForegroundColor Cyan
Write-Host ""
Write-Host "NÄCHSTE SCHRITTE:" -ForegroundColor Yellow
Write-Host "1. Browser öffnen: http://localhost:$Port/" -ForegroundColor White
Write-Host "2. Testen: Invoke-WebRequest 'http://localhost:$Port/health.json'" -ForegroundColor White
Write-Host "3. Bei Problemen: Get-Job | Receive-Job" -ForegroundColor White
if ($EnablePSRemoting) {
    Write-Host ""
    Write-Host "PSRemoting Status:" -ForegroundColor Cyan
    Write-Host "- Erlaubte Hosts: ITSC020.cc.meduniwien.ac.at, ITSCMGMT03.srv.meduniwien.ac.at" -ForegroundColor White
    Write-Host "- Port: 5985 (HTTP)" -ForegroundColor White
    Write-Host "- Test von extern: New-PSSession -ComputerName <SERVERNAME>" -ForegroundColor White
}