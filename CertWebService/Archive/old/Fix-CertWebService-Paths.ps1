<#
.SYNOPSIS
    Quick Fix für CertWebService Path-Problem

.DESCRIPTION
    Behebt das Problem, dass ScanCertificates.ps1 in das falsche Verzeichnis schreibt.
    Deployed die korrigierte Version auf Remote-Server.

.PARAMETER Servers
    Liste der Zielserver

.PARAMETER UpdateScanScript
    Aktualisiert ScanCertificates.ps1 auf den Servern

.PARAMETER RunScanNow
    Führt den Scan sofort nach dem Update aus

.VERSION
    1.0.0

.RULEBOOK
    v10.0.2
#>

param(
    [string[]]$Servers = @(
        "itscmgmt03.srv.meduniwien.ac.at",
        "wsus.srv.meduniwien.ac.at"
    ),
    [switch]$UpdateScanScript,
    [switch]$RunScanNow
)

$ErrorActionPreference = 'Continue'

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CertWebService Path Fix Deployment v1.0.0                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$scanScriptSource = Join-Path $scriptDir "ScanCertificates.ps1"

if (-not (Test-Path $scanScriptSource)) {
    Write-Host "❌ ScanCertificates.ps1 nicht gefunden in: $scriptDir" -ForegroundColor Red
    exit 1
}

Write-Host "`n📋 Script gefunden: $scanScriptSource" -ForegroundColor Green
Write-Host "🎯 Zielserver: $($Servers -join ', ')" -ForegroundColor Yellow
Write-Host ""

foreach ($server in $Servers) {
    Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "🖥️  Server: $server" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    
    try {
        # Test connectivity
        Write-Host "`n[1/5] Teste Verbindung..." -ForegroundColor Cyan
        $ping = Test-Connection -ComputerName $server -Count 1 -Quiet
        if (-not $ping) {
            Write-Host "  ❌ Server nicht erreichbar" -ForegroundColor Red
            continue
        }
        Write-Host "  ✅ Server erreichbar" -ForegroundColor Green
        
        # Check paths
        Write-Host "`n[2/5] Prüfe Verzeichnisstruktur..." -ForegroundColor Cyan
        $wwwrootPath = "\\$server\c$\inetpub\wwwroot\CertWebService"
        $altPath = "\\$server\c$\inetpub\CertWebService"
        
        $wwwrootExists = Test-Path $wwwrootPath
        $altExists = Test-Path $altPath
        
        Write-Host "  wwwroot path: " -NoNewline
        if ($wwwrootExists) {
            Write-Host "✅ Vorhanden" -ForegroundColor Green
        } else {
            Write-Host "❌ Fehlt (wird erstellt)" -ForegroundColor Yellow
            New-Item -Path $wwwrootPath -ItemType Directory -Force | Out-Null
            Write-Host "  ✅ Verzeichnis erstellt" -ForegroundColor Green
        }
        
        Write-Host "  Alternative path: " -NoNewline
        if ($altExists) {
            Write-Host "✅ Vorhanden" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Fehlt" -ForegroundColor Yellow
        }
        
        # Check IIS site configuration
        Write-Host "`n[3/5] Prüfe IIS Konfiguration..." -ForegroundColor Cyan
        try {
            $iisInfo = Invoke-Command -ComputerName $server -ScriptBlock {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                Get-Website | Where-Object { $_.Name -like "*CertWeb*" } | Select-Object Name, State, PhysicalPath, @{Name="Port";Expression={ ($_.Bindings.Collection | Where-Object {$_.protocol -eq 'http'})[0].bindingInformation -replace '.*:(\d+):.*','$1' }}
            } -ErrorAction Stop
            
            if ($iisInfo) {
                Write-Host "  Site Name: $($iisInfo.Name)" -ForegroundColor White
                Write-Host "  Status: $($iisInfo.State)" -ForegroundColor $(if($iisInfo.State -eq 'Started'){'Green'}else{'Yellow'})
                Write-Host "  Physical Path: $($iisInfo.PhysicalPath)" -ForegroundColor White
                Write-Host "  Port: $($iisInfo.Port)" -ForegroundColor Cyan
                
                $targetPath = $iisInfo.PhysicalPath
            } else {
                Write-Host "  ⚠️  Keine CertWebService IIS Site gefunden" -ForegroundColor Yellow
                $targetPath = $wwwrootPath
            }
        } catch {
            Write-Host "  ⚠️  IIS-Prüfung fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
            $targetPath = $wwwrootPath
        }
        
        # Update ScanCertificates.ps1
        if ($UpdateScanScript) {
            Write-Host "`n[4/5] Update ScanCertificates.ps1..." -ForegroundColor Cyan
            
            # Backup existing script
            $existingScript = Join-Path $targetPath.Replace('C:\', "\\$server\c$\") "ScanCertificates.ps1"
            if (Test-Path $existingScript) {
                $backupName = "ScanCertificates_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"
                $backupPath = Join-Path (Split-Path $existingScript -Parent) $backupName
                Copy-Item $existingScript -Destination $backupPath -Force
                Write-Host "  📋 Backup erstellt: $backupName" -ForegroundColor Gray
            }
            
            # Copy new script
            $destScript = Join-Path $targetPath.Replace('C:\', "\\$server\c$\") "ScanCertificates.ps1"
            Copy-Item $scanScriptSource -Destination $destScript -Force
            Write-Host "  ✅ ScanCertificates.ps1 aktualisiert" -ForegroundColor Green
        } else {
            Write-Host "`n[4/5] Update ScanCertificates.ps1... ÜBERSPRUNGEN (verwende -UpdateScanScript)" -ForegroundColor Yellow
        }
        
        # Run scan now
        if ($RunScanNow) {
            Write-Host "`n[5/5] Führe Certificate Scan aus..." -ForegroundColor Cyan
            
            try {
                $scanResult = Invoke-Command -ComputerName $server -ScriptBlock {
                    param($scriptPath)
                    
                    if (Test-Path $scriptPath) {
                        $output = & powershell.exe -ExecutionPolicy Bypass -File $scriptPath 2>&1
                        return @{
                            Success = $?
                            Output = $output
                        }
                    } else {
                        return @{
                            Success = $false
                            Output = "Script not found: $scriptPath"
                        }
                    }
                } -ArgumentList ($targetPath + "\ScanCertificates.ps1") -ErrorAction Stop
                
                if ($scanResult.Success) {
                    Write-Host "  ✅ Certificate Scan erfolgreich" -ForegroundColor Green
                    
                    # Check result
                    Start-Sleep -Seconds 2
                    $certsJsonPath = Join-Path $targetPath.Replace('C:\', "\\$server\c$\") "certificates.json"
                    if (Test-Path $certsJsonPath) {
                        $certsJson = Get-Content $certsJsonPath -Raw | ConvertFrom-Json
                        Write-Host "  📊 Gefundene Zertifikate: $($certsJson.total_count)" -ForegroundColor Cyan
                    }
                } else {
                    Write-Host "  ⚠️  Scan-Ausführung mit Warnung" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  ❌ Scan-Fehler: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "`n[5/5] Certificate Scan... ÜBERSPRUNGEN (verwende -RunScanNow)" -ForegroundColor Yellow
        }
        
        # Verify certificates.json
        Write-Host "`n📊 Verifiziere certificates.json..." -ForegroundColor Cyan
        $certsJsonPath = Join-Path $targetPath.Replace('C:\', "\\$server\c$\") "certificates.json"
        
        if (Test-Path $certsJsonPath) {
            $fileInfo = Get-Item $certsJsonPath
            Write-Host "  Datei: certificates.json" -ForegroundColor White
            Write-Host "  Größe: $([Math]::Round($fileInfo.Length/1KB,2)) KB" -ForegroundColor White
            Write-Host "  Letzte Änderung: $($fileInfo.LastWriteTime)" -ForegroundColor White
            
            try {
                $certsJson = Get-Content $certsJsonPath -Raw | ConvertFrom-Json
                Write-Host "  Zertifikate: $($certsJson.total_count)" -ForegroundColor $(if($certsJson.total_count -gt 0){'Green'}else{'Yellow'})
            } catch {
                Write-Host "  ⚠️  JSON Parse Fehler" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ❌ certificates.json nicht gefunden!" -ForegroundColor Red
        }
        
        Write-Host "`n✅ Server $server abgeschlossen" -ForegroundColor Green
        
    } catch {
        Write-Host "`n❌ Fehler bei $server`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Deployment abgeschlossen!                                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 Nächste Schritte:" -ForegroundColor Yellow
Write-Host "  1. Führe aus mit -UpdateScanScript zum Script-Update" -ForegroundColor White
Write-Host "  2. Führe aus mit -RunScanNow zum sofortigen Scan" -ForegroundColor White
Write-Host "  3. Teste API: Invoke-RestMethod -Uri 'http://SERVER:9080/certificates.json'" -ForegroundColor White
Write-Host ""
