#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Admin-Schnellzugriff für ResetProfile System (Produktionsumgebung)

.DESCRIPTION
    Vereinfachter Zugriff auf das ResetProfile System für Administratoren.
    Dieses Skript befindet sich in der Produktionsumgebung und bietet
    schnellen Zugriff auf alle Funktionen des PowerShell Profile Reset Systems.

.PARAMETER Setup
    Startet die Konfigurationsoberfläche

.PARAMETER Reset  
    Führt das PowerShell Profile Reset durch

.PARAMETER WhatIf
    Simuliert das Reset ohne Änderungen

.PARAMETER Status
    Zeigt den aktuellen Systemstatus an

.EXAMPLE
    .\Admin-ResetProfile.ps1 -Setup
    Startet die Konfigurationsoberfläche

.EXAMPLE
    .\Admin-ResetProfile.ps1 -Reset -WhatIf  
    Simuliert das Profile Reset

.EXAMPLE
    .\Admin-ResetProfile.ps1 -Reset
    Führt das Profile Reset durch

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        1.0.0
    Regelwerk:      v9.6.0
    Location:       \\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\ResetProfile
    Created:        2025-09-27
#>

[CmdletBinding()]
param(
    [Switch]$Setup,
    [Switch]$Reset,
    [Switch]$WhatIf,
    [Switch]$Status
)

# Produktionsverzeichnis
$ProdPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\ResetProfile"
$MainScript = Join-Path $ProdPath "Reset-PowerShellProfiles.ps1"

function Show-AdminHeader {
    Write-Host "`n" + "="*70 -ForegroundColor Green
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "🏢 MedUni Wien - PowerShell Profile Reset System" -ForegroundColor Green
        Write-Host "⚡ Admin-Interface (Produktionsumgebung)" -ForegroundColor Cyan
    } else {
        Write-Host "[ADMIN] MedUni Wien - PowerShell Profile Reset System" -ForegroundColor Green  
        Write-Host "[PROD] Admin-Interface (Produktionsumgebung)" -ForegroundColor Cyan
    }
    Write-Host "="*70 -ForegroundColor Green
    Write-Host "Produktionsverzeichnis: $ProdPath" -ForegroundColor Gray
    Write-Host "Benutzer: $env:USERNAME@$env:COMPUTERNAME" -ForegroundColor Gray
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
}

function Show-SystemStatus {
    Write-Host "[STATUS] SYSTEMSTATUS" -ForegroundColor Yellow
    Write-Host "-" * 50
    
    # Version Check
    try {
        $versionFile = Join-Path $ProdPath "VERSION.ps1"
        if (Test-Path $versionFile) {
            $content = Get-Content $versionFile -Raw
            if ($content -match '\$ScriptVersion\s*=\s*"([^"]+)"') {
                Write-Host "[OK] System Version: $($matches[1])" -ForegroundColor Green
            }
            if ($content -match '\$RegelwerkVersion\s*=\s*"([^"]+)"') {
                Write-Host "[OK] Regelwerk: $($matches[1])" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "[ERROR] Version-Check fehlgeschlagen" -ForegroundColor Red
    }
    
    # File Check
    $criticalFiles = @(
        "Reset-PowerShellProfiles.ps1",
        "VERSION.ps1", 
        "Modules\FL-Config.psm1",
        "Modules\FL-Logging.psm1",
        "Modules\FL-Utils.psm1"
    )
    
    foreach ($file in $criticalFiles) {
        $filePath = Join-Path $ProdPath $file
        if (Test-Path $filePath) {
            $size = (Get-Item $filePath).Length
            Write-Host "[OK] $file ($size Bytes)" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] $file - FEHLT!" -ForegroundColor Red
        }
    }
    
    # Recent Logs
    $logPath = Join-Path $ProdPath "LOG"
    if (Test-Path $logPath) {
        $recentLogs = Get-ChildItem $logPath -Filter "*$(Get-Date -Format 'yyyy-MM-dd')*" | 
                     Select-Object -First 3
        if ($recentLogs) {
            Write-Host "`n[LOGS] Heutige Logs:" -ForegroundColor Cyan
            $recentLogs | ForEach-Object {
                $size = [math]::Round($_.Length / 1KB, 1)
                Write-Host "   $($_.Name) (${size} KB)" -ForegroundColor Gray
            }
        }
    }
    
    # Backup Status  
    $backupPath = Join-Path $ProdPath "Backup\Sync-Backups"
    if (Test-Path $backupPath) {
        $latestBackup = Get-ChildItem $backupPath | 
                       Sort-Object LastWriteTime -Descending | 
                       Select-Object -First 1
        if ($latestBackup) {
            Write-Host "`n[BACKUP] Letztes Backup: $($latestBackup.Name)" -ForegroundColor Magenta
            Write-Host "   Erstellt: $($latestBackup.LastWriteTime)" -ForegroundColor Gray
        }
    }
}

function Invoke-AdminAction {
    if ($Status) {
        Show-SystemStatus
        return
    }
    
    if ($Setup) {
        Write-Host "[CFG] Starte Konfigurationsoberfläche..." -ForegroundColor Yellow
        & $MainScript -Setup
        return
    }
    
    if ($Reset) {
        if ($WhatIf) {
            Write-Host "[SIM] Simuliere Profile Reset (WhatIf-Modus)..." -ForegroundColor Yellow
            & $MainScript -WhatIf
        } else {
            Write-Host "[WARN] ACHTUNG: Profile Reset wird durchgeführt!" -ForegroundColor Red
            Write-Host "Fortfahren? (J/N): " -NoNewline -ForegroundColor Yellow
            $response = Read-Host
            if ($response -match '^[JjYy]') {
                Write-Host "[START] Führe Profile Reset durch..." -ForegroundColor Green
                & $MainScript
            } else {
                Write-Host "[CANCEL] Vorgang abgebrochen." -ForegroundColor Yellow
            }
        }
        return
    }
    
    # Kein Parameter - Show Help
    Show-AdminHelp
}

function Show-AdminHelp {
    Write-Host "[HELP] VERFÜGBARE AKTIONEN" -ForegroundColor Cyan
    Write-Host "-" * 50
    Write-Host "  -Status    " -NoNewline -ForegroundColor Green; Write-Host "Zeigt Systemstatus an"
    Write-Host "  -Setup     " -NoNewline -ForegroundColor Green; Write-Host "Startet Konfigurationsoberfläche"
    Write-Host "  -Reset     " -NoNewline -ForegroundColor Green; Write-Host "Führt Profile Reset durch"
    Write-Host "  -WhatIf    " -NoNewline -ForegroundColor Green; Write-Host "Kombiniert mit -Reset für Simulation"
    Write-Host ""
    Write-Host "[EXAMPLES] BEISPIELE:" -ForegroundColor Yellow
    Write-Host "  .\Admin-ResetProfile.ps1 -Status" -ForegroundColor Gray
    Write-Host "  .\Admin-ResetProfile.ps1 -Setup" -ForegroundColor Gray
    Write-Host "  .\Admin-ResetProfile.ps1 -Reset -WhatIf" -ForegroundColor Gray
    Write-Host "  .\Admin-ResetProfile.ps1 -Reset" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[ACCESS] Direkter Zugriff:" -ForegroundColor Magenta
    Write-Host "  $MainScript" -ForegroundColor Gray
}

# Main Execution
Show-AdminHeader

if (-not (Test-Path $MainScript)) {
    Write-Host "[ERROR] FEHLER: Hauptskript nicht gefunden!" -ForegroundColor Red
    Write-Host "Erwartet: $MainScript" -ForegroundColor Gray
    exit 1
}

Invoke-AdminAction