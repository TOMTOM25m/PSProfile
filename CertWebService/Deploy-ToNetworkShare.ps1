#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy CertWebService to Network Share
    
.DESCRIPTION
    Deployed CertWebService Scripts und Dokumentation auf Netzwerk-Share
    fuer zentrale Installation auf mehreren Servern
    
.PARAMETER NetworkPath
    Netzwerk-Share Pfad (Default: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService)
    
.PARAMETER Force
    Ueberschreibt existierende Dateien ohne Nachfrage
    
.EXAMPLE
    .\Deploy-ToNetworkShare.ps1
    Deployed mit Bestaetigung
    
.EXAMPLE
    .\Deploy-ToNetworkShare.ps1 -Force
    Deployed ohne Bestaetigung
    
.NOTES
    Author:  Flecki (Tom) Garnreiter
    Version: v1.0.0
    Date:    2025-10-08
    Regelwerk: v10.1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Configuration

# Dateien zum Deployment
$script:FilesToDeploy = @{
    Scripts = @(
        "Install-CertWebService.ps1",
        "Setup-CertWebService-Scheduler.ps1",
        "CertWebService.ps1",
        "ScanCertificates.ps1"
    )
    Documentation = @(
        "INSTALLATION-SCHEDULER-GUIDE.md",
        "REGELWERK-UPDATE-SUMMARY.md",
        "README.md"
    )
    Batch = @(
        "Install.bat"
    )
}

# Log-Datei
$script:LogFile = Join-Path $PSScriptRoot "Deploy-ToNetworkShare_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

#endregion

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Logging # Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
Functions

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to file
    try {
        Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8
    } catch {
        # Ignore
    }
    
    # Console
    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        default   { Write-Host $logMessage -ForegroundColor Gray }
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Show-Banner {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Deployment # Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
Functions

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Test-NetworkPath {
    Show-Banner "NETZWERK-ZUGRIFF PRUEFEN"
    Write-Log "Pruefe Netzwerk-Share: $NetworkPath" -Level INFO
    
    try {
        if (Test-Path $NetworkPath) {
            Write-Log "Netzwerk-Share erreichbar: $NetworkPath" -Level SUCCESS
            
            # Teste Schreibrechte
            $testFile = Join-Path $NetworkPath "_test_write_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
            try {
                "test" | Out-File -FilePath $testFile -Encoding UTF8 -Force
                Remove-Item -Path $testFile -Force
                Write-Log "Schreibrechte: OK" -Level SUCCESS
                return $true
            } catch {
                Write-Log "Keine Schreibrechte auf $NetworkPath" -Level ERROR
                return $false
            }
        } else {
            Write-Log "Netzwerk-Share nicht erreichbar: $NetworkPath" -Level ERROR
            Write-Host ""
            Write-Host "Moeglicherweise:" -ForegroundColor Yellow
            Write-Host "  - Keine Netzwerk-Verbindung" -ForegroundColor Gray
            Write-Host "  - Fehlende Zugriffsrechte" -ForegroundColor Gray
            Write-Host "  - Share nicht gemountet" -ForegroundColor Gray
            Write-Host ""
            return $false
        }
    } catch {
        Write-Log "Fehler beim Zugriff auf Netzwerk-Share: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function New-NetworkDirectory {
    Write-Host ""
    Write-Host "[STEP 1] Verzeichnis-Struktur erstellen..." -ForegroundColor Yellow
    Write-Log "Erstelle Verzeichnis-Struktur auf Netzwerk-Share..." -Level INFO
    
    $directories = @(
        $NetworkPath,
        (Join-Path $NetworkPath "Scripts"),
        (Join-Path $NetworkPath "Documentation"),
        (Join-Path $NetworkPath "Batch")
    )
    
    foreach ($dir in $directories) {
        try {
            if (-not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Log "Verzeichnis erstellt: $dir" -Level SUCCESS
            } else {
                Write-Log "Verzeichnis existiert: $dir" -Level INFO
            }
        } catch {
            Write-Log "Fehler beim Erstellen von $dir - $($_.Exception.Message)" -Level ERROR
            return $false
        }
    }
    
    Write-Host ""
    return $true
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Copy-FilesToNetwork {
    Show-Banner "DATEIEN KOPIEREN"
    Write-Log "Kopiere Dateien zum Netzwerk-Share..." -Level INFO
    
    $sourceDir = $PSScriptRoot
    $copiedCount = 0
    $totalCount = 0
    
    # Scripts
    Write-Host "[CATEGORY] Scripts..." -ForegroundColor Cyan
    foreach ($file in $script:FilesToDeploy.Scripts) {
        $totalCount++
        $sourcePath = Join-Path $sourceDir $file
        $targetPath = Join-Path $NetworkPath $file
        
        if (Test-Path $sourcePath) {
            try {
                # MD5 Hash vergleichen
                $needsCopy = $true
                if (Test-Path $targetPath) {
                    $sourceHash = (Get-FileHash -Path $sourcePath -Algorithm MD5).Hash
                    $targetHash = (Get-FileHash -Path $targetPath -Algorithm MD5).Hash
                    
                    if ($sourceHash -eq $targetHash) {
                        Write-Host "  [SKIP] $file (identisch)" -ForegroundColor Gray
                        Write-Log "Datei unveraendert: $file" -Level INFO
                        $needsCopy = $false
                        $copiedCount++
                    }
                }
                
                if ($needsCopy) {
                    Copy-Item -Path $sourcePath -Destination $targetPath -Force
                    $size = (Get-Item $sourcePath).Length / 1KB
                    Write-Host "  [COPY] $file ($("{0:N1}" -f $size) KB)" -ForegroundColor Green
                    Write-Log "Datei kopiert: $file ($("{0:N1}" -f $size) KB)" -Level SUCCESS
                    $copiedCount++
                }
            } catch {
                Write-Host "  [ERROR] $file - $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "Fehler beim Kopieren von $file - $($_.Exception.Message)" -Level ERROR
            }
        } else {
            Write-Host "  [WARN] $file nicht gefunden" -ForegroundColor Yellow
            Write-Log "Quelldatei nicht gefunden: $file" -Level WARNING
        }
    }
    
    Write-Host ""
    
    # Documentation
    Write-Host "[CATEGORY] Documentation..." -ForegroundColor Cyan
    foreach ($file in $script:FilesToDeploy.Documentation) {
        $totalCount++
        $sourcePath = Join-Path $sourceDir $file
        $targetPath = Join-Path $NetworkPath $file
        
        if (Test-Path $sourcePath) {
            try {
                Copy-Item -Path $sourcePath -Destination $targetPath -Force
                $size = (Get-Item $sourcePath).Length / 1KB
                Write-Host "  [COPY] $file ($("{0:N1}" -f $size) KB)" -ForegroundColor Green
                Write-Log "Datei kopiert: $file" -Level SUCCESS
                $copiedCount++
            } catch {
                Write-Host "  [ERROR] $file - $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "Fehler beim Kopieren von $file - $($_.Exception.Message)" -Level ERROR
            }
        } else {
            Write-Host "  [WARN] $file nicht gefunden" -ForegroundColor Yellow
            Write-Log "Quelldatei nicht gefunden: $file" -Level WARNING
        }
    }
    
    Write-Host ""
    
    # Batch Files
    Write-Host "[CATEGORY] Batch Files..." -ForegroundColor Cyan
    foreach ($file in $script:FilesToDeploy.Batch) {
        $totalCount++
        $sourcePath = Join-Path $sourceDir $file
        
        if (-not (Test-Path $sourcePath)) {
            # Erstelle Install.bat wenn nicht vorhanden
            if ($file -eq "Install.bat") {
                Write-Host "  [CREATE] $file (neu erstellt)" -ForegroundColor Cyan
                
                # Batch Content als Array
                $batLines = @()
                $batLines += "@echo off"
                $batLines += ":: ================================================================="
                $batLines += ":: Install-CertWebService.bat"
                $batLines += ":: Network Share Installation Launcher"
                $batLines += ":: ================================================================="
                $batLines += ""
                $batLines += "echo."
                $batLines += "echo ====================================================================="
                $batLines += "echo   CertWebService Installation vom Netzlaufwerk"
                $batLines += "echo   Version 2.6.0 - Regelwerk v10.1.0"
                $batLines += "echo ====================================================================="
                $batLines += "echo."
                $batLines += ""
                $batLines += ":: Admin-Rechte pruefen"
                $batLines += "net session >nul 2>&1"
                $batLines += "if %errorLevel% NEQ 0 ("
                $batLines += "    echo [ERROR] Administrator-Rechte erforderlich!"
                $batLines += "    echo."
                $batLines += "    pause"
                $batLines += "    exit /b 1"
                $batLines += ")"
                $batLines += ""
                $batLines += "echo [INFO] Administrator-Rechte: OK"
                $batLines += "echo."
                $batLines += ""
                $batLines += ":: Network Share Path"
                $batLines += 'set "NETWORK_SHARE=%~dp0"'
                $batLines += ""
                $batLines += "echo [INFO] Netzwerk-Pfad: %NETWORK_SHARE%"
                $batLines += "echo."
                $batLines += ""
                $batLines += ":: PowerShell Script ausfuehren"
                $batLines += "echo [INFO] Starte CertWebService Installation..."
                $batLines += "echo."
                $batLines += ""
                $batLines += 'powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%NETWORK_SHARE%Install-CertWebService.ps1"'
                $batLines += ""
                $batLines += "if %errorLevel% EQU 0 ("
                $batLines += "    echo."
                $batLines += "    echo ====================================================================="
                $batLines += "    echo [SUCCESS] Installation erfolgreich!"
                $batLines += "    echo ====================================================================="
                $batLines += ") else ("
                $batLines += "    echo."
                $batLines += "    echo ====================================================================="
                $batLines += "    echo [ERROR] Installation fehlgeschlagen!"
                $batLines += "    echo ====================================================================="
                $batLines += ")"
                $batLines += ""
                $batLines += "pause"
                
                $sourcePath = Join-Path $PSScriptRoot $file
                $batLines | Out-File -FilePath $sourcePath -Encoding ASCII -Force
            }
        }
        
        $targetPath = Join-Path $NetworkPath $file
        
        if (Test-Path $sourcePath) {
            try {
                Copy-Item -Path $sourcePath -Destination $targetPath -Force
                $size = (Get-Item $sourcePath).Length / 1KB
                Write-Host "  [COPY] $file ($("{0:N1}" -f $size) KB)" -ForegroundColor Green
                Write-Log "Datei kopiert: $file" -Level SUCCESS
                $copiedCount++
            } catch {
                Write-Host "  [ERROR] $file - $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "Fehler beim Kopieren von $file - $($_.Exception.Message)" -Level ERROR
            }
        }
    }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Log "$copiedCount von $totalCount Dateien erfolgreich kopiert" -Level INFO
    
    return $copiedCount -gt 0
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function New-NetworkInstallationReadme {
    Show-Banner "README ERSTELLEN"
    Write-Log "Erstelle NETWORK-INSTALLATION.md..." -Level INFO
    
    $readmePath = Join-Path $NetworkPath "NETWORK-INSTALLATION.md"
    
    $lines = @()
    $lines += "# CertWebService - Netzwerk-Installation"
    $lines += ""
    $lines += "## Netzwerk-Pfad"
    $lines += ""
    $lines += "$NetworkPath"
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## Quick Start"
    $lines += ""
    $lines += "### Option 1: Batch-File (EMPFOHLEN)"
    $lines += ""
    $lines += "1. Als Administrator ausfuehren: Install.bat"
    $lines += "2. Folge den Anweisungen"
    $lines += ""
    $lines += "### Option 2: PowerShell"
    $lines += ""
    $lines += "Als Administrator: .\Install-CertWebService.ps1"
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## Dateien"
    $lines += ""
    $lines += "- Install.bat : Batch-Launcher"
    $lines += "- Install-CertWebService.ps1 : Installations-Script"
    $lines += "- Setup-CertWebService-Scheduler.ps1 : Scheduler-Setup"
    $lines += "- CertWebService.ps1 : HTTP Web Service"
    $lines += "- ScanCertificates.ps1 : Zertifikats-Scanner"
    $lines += "- INSTALLATION-SCHEDULER-GUIDE.md : Dokumentation"
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## Installation Modi"
    $lines += ""
    $lines += "Full: .\Install-CertWebService.ps1 -Mode Full"
    $lines += "Update: .\Install-CertWebService.ps1 -Mode Update"
    $lines += "Repair: .\Install-CertWebService.ps1 -Mode Repair"
    $lines += "Remove: .\Install-CertWebService.ps1 -Mode Remove"
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "Version: v2.6.0"
    $lines += "Regelwerk: v10.1.0"
    $lines += "Deployment: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    try {
        $lines | Out-File -FilePath $readmePath -Encoding UTF8 -Force
        Write-Log "NETWORK-INSTALLATION.md erstellt: $readmePath" -Level SUCCESS
        return $true
    } catch {
        Write-Log "Fehler beim Erstellen von NETWORK-INSTALLATION.md: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Show-DeploymentSummary {
    Show-Banner "DEPLOYMENT ZUSAMMENFASSUNG"
    
    Write-Host "Netzwerk-Pfad:" -ForegroundColor Cyan
    Write-Host "  $NetworkPath" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Dateien auf Netzwerk-Share:" -ForegroundColor Cyan
    try {
        $files = Get-ChildItem -Path $NetworkPath -File -ErrorAction Stop
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum / 1KB
        
        Write-Host ""
        $files | Sort-Object Name | ForEach-Object {
            $size = $_.Length / 1KB
            Write-Host "  $($_.Name)" -NoNewline -ForegroundColor White
            Write-Host " ($("{0:N1}" -f $size) KB)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "  Gesamt: $($files.Count) Dateien, $("{0:N1}" -f $totalSize) KB" -ForegroundColor Cyan
    } catch {
        Write-Log "Fehler beim Auflisten der Dateien: $($_.Exception.Message)" -Level ERROR
    }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
}

#endregion

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Main Execution

# Script Start
Show-Banner "CERTWEBSERVICE - NETWORK DEPLOYMENT v1.0.0"

Write-Host "Source: $PSScriptRoot" -ForegroundColor Gray
Write-Host "Target: $NetworkPath" -ForegroundColor Gray
Write-Host "Log: $script:LogFile" -ForegroundColor Gray
Write-Host ""

Write-Log "=== DEPLOYMENT GESTARTET ===" -Level INFO
Write-Log "Source: $PSScriptRoot" -Level INFO
Write-Log "Target: $NetworkPath" -Level INFO

# Test Network Access
$networkOk = Test-NetworkPath

if (-not $networkOk) {
    Write-Host ""
    Write-Host "[FATAL] Netzwerk-Share nicht erreichbar oder keine Schreibrechte!" -ForegroundColor Red
    Write-Host "Deployment kann nicht fortgesetzt werden." -ForegroundColor Red
    Write-Log "Deployment abgebrochen: Netzwerk-Share nicht erreichbar" -Level ERROR
    exit 1
}

# Confirmation
if (-not $Force) {
    Write-Host ""
    Write-Host "Dateien werden deployed nach:" -ForegroundColor Yellow
    Write-Host "  $NetworkPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Fortfahren? [J/N]: " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ($response -ne "J" -and $response -ne "j") {
        Write-Log "Deployment vom Benutzer abgebrochen" -Level INFO
        exit 0
    }
}

# Create Directory Structure
$dirOk = New-NetworkDirectory

if (-not $dirOk) {
    Write-Host ""
    Write-Host "[FATAL] Verzeichnis-Struktur konnte nicht erstellt werden!" -ForegroundColor Red
    Write-Log "Deployment abgebrochen: Verzeichnis-Struktur fehlgeschlagen" -Level ERROR
    exit 1
}

# Copy Files
$copyOk = Copy-FilesToNetwork

if (-not $copyOk) {
    Write-Host ""
    Write-Host "[WARNING] Einige Dateien konnten nicht kopiert werden!" -ForegroundColor Yellow
    Write-Log "Deployment mit Warnungen abgeschlossen" -Level WARNING
}

# Create README
$readmeOk = New-NetworkInstallationReadme

# Show Summary
Show-DeploymentSummary

# Final Message
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT ABGESCHLOSSEN" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "NAECHSTE SCHRITTE:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Auf Ziel-Server als Administrator:" -ForegroundColor White
Write-Host "     cd '$NetworkPath'" -ForegroundColor Gray
Write-Host "     .\Install.bat" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Oder PowerShell:" -ForegroundColor White
Write-Host "     .\Install-CertWebService.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Dokumentation:" -ForegroundColor White
Write-Host "     INSTALLATION-SCHEDULER-GUIDE.md" -ForegroundColor Gray
Write-Host ""

Write-Log "=== DEPLOYMENT BEENDET ===" -Level SUCCESS

#endregion

