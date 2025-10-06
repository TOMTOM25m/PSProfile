#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy-To-NetworkShare.ps1 - Universelles Deployment-Script mit ROBOCOPY
.DESCRIPTION
    Deployed CertWebService und CertSurv auf das Netzlaufwerk
    Verwendet ausschliesslich ROBOCOPY fuer alle Datei-Operationen
.NOTES
    Version: 1.0.0
    Regelwerk: v10.0.2
    Author: GitHub Copilot
    Date: 2025-10-06
    WICHTIG: Verwendet IMMER ROBOCOPY - NIEMALS Copy-Item oder Move-Item!
.PARAMETER Component
    Welche Komponente soll deployed werden: CertWebService, CertSurv oder All
.PARAMETER Mirror
    Wenn gesetzt, wird /MIR verwendet (komplette Synchronisation)
.PARAMETER WhatIf
    Zeigt nur an, was gemacht werden wuerde (Dry-Run)
.EXAMPLE
    .\Deploy-To-NetworkShare.ps1 -Component All
    Deployed beide Komponenten
.EXAMPLE
    .\Deploy-To-NetworkShare.ps1 -Component CertWebService -WhatIf
    Zeigt an, was fuer CertWebService deployed werden wuerde
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("CertWebService", "CertSurv", "All")]
    [string]$Component = "All",
    
    [Parameter(Mandatory=$false)]
    [switch]$Mirror,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Continue"

# Konfiguration
$Config = @{
    BaseSourcePath = "F:\DEV\repositories"
    NetworkShareBase = "\\itscmgmt03.srv.meduniwien.ac.at\iso"
    
    CertWebService = @{
        SourcePath = "F:\DEV\repositories\CertWebService"
        TargetPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
        Files = @(
            "CertWebService.ps1"
            "Setup-CertWebService.ps1"
            "Fix-Installation-v1.3-ASCII.ps1"
            "VERSION.ps1"
            "README.md"
        )
        Directories = @(
            "Config"
            "Modules"
        )
    }
    
    CertSurv = @{
        SourcePath = "F:\DEV\repositories\CertSurv"
        TargetPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv"
        Files = @(
            "Setup-CertSurv.ps1"
            "VERSION.ps1"
            "DEPLOYMENT-README.md"
            "README.md"
        )
        Directories = @(
            "Config"
            "Modules"
            "Core-Applications"
        )
    }
}

# ROBOCOPY Standard-Parameter
$RobocopyBaseParams = @(
    "/Z"        # Restartable mode
    "/R:3"      # 3 Retries
    "/W:5"      # 5 Sekunden Wartezeit
    "/NP"       # Kein Progress
    "/NDL"      # Keine Directory-Liste
    "/NFL"      # Keine File-Liste (nur Summary)
)

if ($WhatIf) {
    $RobocopyBaseParams += "/L"  # List only (Dry-Run)
}

# Funktion: ROBOCOPY Einzelne Dateien
function Invoke-RobocopyFiles {
    param(
        [string]$Source,
        [string]$Target,
        [string[]]$Files,
        [string]$ComponentName
    )
    
    Write-Host "  Deploye Dateien..." -ForegroundColor Cyan
    
    $params = $RobocopyBaseParams + $Files
    
    $result = & robocopy $Source $Target $params 2>&1
    $exitCode = $LASTEXITCODE
    
    # ROBOCOPY Exit Codes: 0-7 = Success, 8+ = Fehler
    if ($exitCode -ge 8) {
        Write-Host "    [FEHLER] ROBOCOPY Exit Code: $exitCode" -ForegroundColor Red
        Write-Host $result
        return $false
    } else {
        $copiedLine = $result | Select-String "Copied :" | Select-Object -First 1
        if ($copiedLine) {
            $copiedFiles = $copiedLine.ToString() -replace '\s+', ' '
            Write-Host "    [OK] $copiedFiles" -ForegroundColor Green
        } else {
            Write-Host "    [OK] Dateien deployed (Exit Code: $exitCode)" -ForegroundColor Green
        }
        return $true
    }
}

# Funktion: ROBOCOPY Verzeichnisse
function Invoke-RobocopyDirectory {
    param(
        [string]$Source,
        [string]$Target,
        [string]$DirectoryName,
        [bool]$UseMirror
    )
    
    $sourcePath = Join-Path $Source $DirectoryName
    $targetPath = Join-Path $Target $DirectoryName
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host "    [SKIP] $DirectoryName (nicht vorhanden)" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "  Deploye $DirectoryName..." -ForegroundColor Cyan
    
    $params = $RobocopyBaseParams + @("/E")  # Alle Unterverzeichnisse
    
    if ($UseMirror) {
        $params += "/MIR"  # Mirror mode
        Write-Host "    (Mirror-Mode aktiv)" -ForegroundColor Yellow
    }
    
    $result = & robocopy $sourcePath $targetPath $params 2>&1
    $exitCode = $LASTEXITCODE
    
    # ROBOCOPY Exit Codes auswerten
    if ($exitCode -ge 8) {
        Write-Host "    [FEHLER] ROBOCOPY Exit Code: $exitCode" -ForegroundColor Red
        Write-Host $result
        return $false
    } else {
        # Extrahiere Statistiken
        $stats = $result | Select-String "Files :" | Select-Object -First 1
        Write-Host "    [OK] $stats" -ForegroundColor Green
        return $true
    }
}

# Funktion: Deploy Component
function Deploy-Component {
    param(
        [string]$Name,
        [hashtable]$ComponentConfig
    )
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  DEPLOYE: $Name" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Quelle: $($ComponentConfig.SourcePath)" -ForegroundColor Gray
    Write-Host "Ziel:   $($ComponentConfig.TargetPath)" -ForegroundColor Gray
    Write-Host ""
    
    $success = $true
    
    # Pruefe ob Quellverzeichnis existiert
    if (-not (Test-Path $ComponentConfig.SourcePath)) {
        Write-Host "[FEHLER] Quellverzeichnis nicht gefunden!" -ForegroundColor Red
        return $false
    }
    
    # Pruefe Netzlaufwerk
    if (-not (Test-Path (Split-Path $ComponentConfig.TargetPath -Parent))) {
        Write-Host "[FEHLER] Netzlaufwerk nicht erreichbar!" -ForegroundColor Red
        return $false
    }
    
    # Erstelle Zielverzeichnis falls nicht vorhanden
    if (-not (Test-Path $ComponentConfig.TargetPath)) {
        Write-Host "  Erstelle Zielverzeichnis..." -ForegroundColor Yellow
        New-Item -Path $ComponentConfig.TargetPath -ItemType Directory -Force | Out-Null
    }
    
    # Deploy Einzeldateien
    if ($ComponentConfig.Files -and $ComponentConfig.Files.Count -gt 0) {
        $filesSuccess = Invoke-RobocopyFiles -Source $ComponentConfig.SourcePath `
                                             -Target $ComponentConfig.TargetPath `
                                             -Files $ComponentConfig.Files `
                                             -ComponentName $Name
        $success = $success -and $filesSuccess
    }
    
    # Deploy Verzeichnisse
    if ($ComponentConfig.Directories -and $ComponentConfig.Directories.Count -gt 0) {
        foreach ($dir in $ComponentConfig.Directories) {
            $dirSuccess = Invoke-RobocopyDirectory -Source $ComponentConfig.SourcePath `
                                                   -Target $ComponentConfig.TargetPath `
                                                   -DirectoryName $dir `
                                                   -UseMirror $Mirror.IsPresent
            $success = $success -and $dirSuccess
        }
    }
    
    Write-Host ""
    if ($success) {
        Write-Host "[OK] $Name erfolgreich deployed!" -ForegroundColor Green
    } else {
        Write-Host "[FEHLER] $Name deployment hatte Fehler!" -ForegroundColor Red
    }
    
    return $success
}

# Header
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  ROBOCOPY DEPLOYMENT SCRIPT" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Komponente: $Component" -ForegroundColor White
Write-Host "Mirror-Mode: $($Mirror.IsPresent)" -ForegroundColor White
Write-Host "WhatIf-Mode: $($WhatIf.IsPresent)" -ForegroundColor White
Write-Host ""

if ($WhatIf) {
    Write-Host "[INFO] WhatIf-Mode aktiv - keine Dateien werden geaendert!" -ForegroundColor Yellow
    Write-Host ""
}

$overallSuccess = $true

# Deploy basierend auf Component-Parameter
switch ($Component) {
    "CertWebService" {
        $overallSuccess = Deploy-Component -Name "CertWebService" -ComponentConfig $Config.CertWebService
    }
    "CertSurv" {
        $overallSuccess = Deploy-Component -Name "CertSurv" -ComponentConfig $Config.CertSurv
    }
    "All" {
        $webSuccess = Deploy-Component -Name "CertWebService" -ComponentConfig $Config.CertWebService
        $survSuccess = Deploy-Component -Name "CertSurv" -ComponentConfig $Config.CertSurv
        $overallSuccess = $webSuccess -and $survSuccess
    }
}

# Zusammenfassung
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
if ($overallSuccess) {
    Write-Host "  DEPLOYMENT ERFOLGREICH!" -ForegroundColor Green
} else {
    Write-Host "  DEPLOYMENT MIT FEHLERN!" -ForegroundColor Red
}
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $WhatIf) {
    Write-Host "Alle Dateien wurden mit ROBOCOPY deployed!" -ForegroundColor White
    Write-Host ""
    Write-Host "Installieren auf Server:" -ForegroundColor Yellow
    
    if ($Component -eq "CertWebService" -or $Component -eq "All") {
        Write-Host "  & `"\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Setup-CertWebService.ps1`"" -ForegroundColor Gray
    }
    
    if ($Component -eq "CertSurv" -or $Component -eq "All") {
        Write-Host "  & `"\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\Setup-CertSurv.ps1`"" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Exit Code
if ($overallSuccess) {
    exit 0
} else {
    exit 1
}
