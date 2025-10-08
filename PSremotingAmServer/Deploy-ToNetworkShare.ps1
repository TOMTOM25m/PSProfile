#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy-ToNetworkShare - Deployment zu Network Share v1.0.0
    
.DESCRIPTION
    Kopiert alle PSRemoting-Scripts zum zentralen Network Share
    \\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer
    für die Installation auf Remote-Servern.
    
.PARAMETER NetworkShare
    Network Share Pfad (Standard: \\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer)
    
.PARAMETER Force
    Überschreibt existierende Dateien ohne Rückfrage
    
.EXAMPLE
    .\Deploy-ToNetworkShare.ps1
    
.EXAMPLE
    .\Deploy-ToNetworkShare.ps1 -Force
    
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v1.0.0
    Created on:     2025-10-07
    Regelwerk:      v10.0.3
#>

[CmdletBinding()]
param(
    [string]$NetworkShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer",
    
    [switch]$Force = $false
)

# ==========================================
# § 19 PowerShell Version Detection (MANDATORY)
# ==========================================
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

# ==========================================
# Configuration
# ==========================================
$ScriptVersion = "1.0.0"
$SourcePath = $PSScriptRoot

# Dateien die kopiert werden sollen
$FilesToDeploy = @(
    "Configure-PSRemoting.ps1",
    "Show-PSRemotingWhitelist.ps1",
    "Install-PSRemoting.bat",
    "README.md"
)

# Optional: Examples-Verzeichnis
$DirectoriesToDeploy = @(
    "Examples"
)

# ==========================================
# Functions
# ==========================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Level) {
        "SUCCESS" { Write-Host "[$Timestamp] [SUCCESS] $Message" -ForegroundColor Green }
        "WARNING" { Write-Host "[$Timestamp] [WARNING] $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[$Timestamp] [ERROR] $Message" -ForegroundColor Red }
        default   { Write-Host "[$Timestamp] [INFO] $Message" -ForegroundColor White }
    }
}

function Test-NetworkShareAccess {
    param([string]$Path)
    
    try {
        if (Test-Path $Path) {
            # Teste Schreibrechte
            $testFile = Join-Path $Path "test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
            "test" | Out-File -FilePath $testFile -ErrorAction Stop
            Remove-Item -Path $testFile -Force -ErrorAction Stop
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

# ==========================================
# Main Execution
# ==========================================

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Deploy-ToNetworkShare v$ScriptVersion" -ForegroundColor Cyan
Write-Host "  PSRemoting Network Share Deployment" -ForegroundColor Cyan
Write-Host "  Regelwerk: v10.0.3" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Prüfe Source-Verzeichnis
    Write-Log "Source-Verzeichnis: $SourcePath" -Level "INFO"
    
    if (-not (Test-Path $SourcePath)) {
        throw "Source-Verzeichnis nicht gefunden: $SourcePath"
    }
    
    # Prüfe Network Share
    Write-Log "Pruefe Netzwerk-Verbindung..." -Level "INFO"
    Write-Log "Network Share: $NetworkShare" -Level "INFO"
    
    if (-not (Test-Path $NetworkShare)) {
        Write-Log "Network Share existiert nicht - erstelle Verzeichnis..." -Level "WARNING"
        
        try {
            New-Item -Path $NetworkShare -ItemType Directory -Force | Out-Null
            Write-Log "Network Share erstellt" -Level "SUCCESS"
        } catch {
            throw "Konnte Network Share nicht erstellen: $($_.Exception.Message)"
        }
    }
    
    # Teste Zugriffsrechte
    Write-Log "Teste Zugriffsrechte..." -Level "INFO"
    
    if (-not (Test-NetworkShareAccess -Path $NetworkShare)) {
        throw "Keine Schreibrechte auf Network Share: $NetworkShare"
    }
    
    Write-Log "Zugriffsrechte: OK" -Level "SUCCESS"
    Write-Host ""
    
    # Kopiere Dateien
    Write-Log "Kopiere Dateien..." -Level "INFO"
    Write-Host ""
    
    $copiedFiles = 0
    $skippedFiles = 0
    $errorFiles = 0
    
    foreach ($file in $FilesToDeploy) {
        $sourcePath = Join-Path $SourcePath $file
        $destPath = Join-Path $NetworkShare $file
        
        if (-not (Test-Path $sourcePath)) {
            Write-Log "Datei nicht gefunden: $file" -Level "WARNING"
            $skippedFiles++
            continue
        }
        
        try {
            # Prüfe ob Datei bereits existiert
            if ((Test-Path $destPath) -and -not $Force) {
                $sourceHash = (Get-FileHash -Path $sourcePath -Algorithm MD5).Hash
                $destHash = (Get-FileHash -Path $destPath -Algorithm MD5).Hash
                
                if ($sourceHash -eq $destHash) {
                    Write-Log "  [SKIP] $file (identisch)" -Level "INFO"
                    $skippedFiles++
                    continue
                }
            }
            
            # Kopiere Datei
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Log "  [COPY] $file" -Level "SUCCESS"
            $copiedFiles++
            
        } catch {
            Write-Log "  [ERROR] $file - $($_.Exception.Message)" -Level "ERROR"
            $errorFiles++
        }
    }
    
    # Kopiere Verzeichnisse
    Write-Host ""
    Write-Log "Kopiere Verzeichnisse..." -Level "INFO"
    Write-Host ""
    
    foreach ($dir in $DirectoriesToDeploy) {
        $sourcePath = Join-Path $SourcePath $dir
        $destPath = Join-Path $NetworkShare $dir
        
        if (-not (Test-Path $sourcePath)) {
            Write-Log "Verzeichnis nicht gefunden: $dir" -Level "WARNING"
            continue
        }
        
        try {
            if (-not (Test-Path $destPath)) {
                New-Item -Path $destPath -ItemType Directory -Force | Out-Null
            }
            
            # Kopiere alle Dateien im Verzeichnis
            $files = Get-ChildItem -Path $sourcePath -File -Recurse
            
            foreach ($file in $files) {
                $relativePath = $file.FullName.Substring($sourcePath.Length + 1)
                $targetFile = Join-Path $destPath $relativePath
                $targetDir = Split-Path $targetFile -Parent
                
                if (-not (Test-Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                }
                
                Copy-Item -Path $file.FullName -Destination $targetFile -Force
                $copiedFiles++
            }
            
            Write-Log "  [COPY] $dir\ ($($files.Count) Dateien)" -Level "SUCCESS"
            
        } catch {
            Write-Log "  [ERROR] $dir - $($_.Exception.Message)" -Level "ERROR"
            $errorFiles++
        }
    }
    
    # Erstelle README auf Network Share
    Write-Host ""
    Write-Log "Erstelle Network Share README..." -Level "INFO"
    
    $networkReadme = @"
# PSRemoting Network Share Installation

**Network Share:** ``$NetworkShare``

## Installation auf Remote-Server

### Option 1: Batch-File (Empfohlen)

``````batch
\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.bat
``````

**Als Administrator ausführen!**

### Option 2: PowerShell direkt

``````powershell
# Als Administrator ausführen
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Configure-PSRemoting.ps1
``````

### Option 3: Remote-Installation via Invoke-Command

``````powershell
`$cred = Get-Credential
Invoke-Command -ComputerName SERVER01 -Credential `$cred -ScriptBlock {
    & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Configure-PSRemoting.ps1"
}
``````

## Whitelist

Nur folgende Rechner dürfen PSRemoting verwenden:
- ``ITSC020.cc.meduniwien.ac.at``
- ``itscmgmt03.srv.meduniwien.ac.at``

## Dateien

$(foreach ($file in $FilesToDeploy) { "- $file`n" })
$(foreach ($dir in $DirectoriesToDeploy) { "- $dir\`n" })

---
**Deployment:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Version:** $ScriptVersion  
**Regelwerk:** v10.0.3
"@
    
    $networkReadmePath = Join-Path $NetworkShare "NETWORK-INSTALLATION.md"
    $networkReadme | Out-File -FilePath $networkReadmePath -Encoding UTF8 -Force
    Write-Log "Network README erstellt" -Level "SUCCESS"
    
    # Zusammenfassung
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  DEPLOYMENT ABGESCHLOSSEN" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "STATISTIK:" -ForegroundColor Yellow
    Write-Host "  Kopiert: $copiedFiles Dateien" -ForegroundColor Green
    Write-Host "  Übersprungen: $skippedFiles Dateien" -ForegroundColor Gray
    if ($errorFiles -gt 0) {
        Write-Host "  Fehler: $errorFiles Dateien" -ForegroundColor Red
    }
    Write-Host ""
    
    Write-Host "NETWORK SHARE:" -ForegroundColor Yellow
    Write-Host "  $NetworkShare" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "INSTALLATION AUF REMOTE-SERVER:" -ForegroundColor Yellow
    Write-Host "  Als Administrator ausführen:" -ForegroundColor White
    Write-Host "  \\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.bat" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Deployment erfolgreich abgeschlossen" -Level "SUCCESS"
    
} catch {
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Red
    Write-Host "  DEPLOYMENT FEHLGESCHLAGEN" -ForegroundColor Red
    Write-Host "=====================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Log "Fehler: $($_.Exception.Message)" -Level "ERROR"
    Write-Host ""
    exit 1
}
