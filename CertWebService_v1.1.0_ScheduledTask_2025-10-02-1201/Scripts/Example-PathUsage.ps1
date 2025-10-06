#Requires -Version 5.1

<#
.SYNOPSIS
Beispiel-Script f?r die Verwendung der zentralen Pfad-Konfiguration
.DESCRIPTION
Zeigt wie alle Scripts die Config-CertWebService.json f?r Pfade verwenden sollen
Regelwerk v10.0.2 konform | Stand: 02.10.2025
#>

# Lade zentrale Pfad-Management-Funktionen
. "$PSScriptRoot\Get-CertWebServicePaths.ps1"

function Example-UseCentralPaths {
    [CmdletBinding()]
    param()
    
    Write-Host "=== BEISPIEL: ZENTRALE PFAD-NUTZUNG ===" -ForegroundColor Green
    Write-Host ""
    
    # Lade komplette Konfiguration
    $config = Get-CertWebServiceConfig
    if (-not $config) {
        Write-Error "Konfiguration konnte nicht geladen werden!"
        return
    }
    
    Write-Host " Konfiguration geladen von: Config\Config-CertWebService.json" -ForegroundColor Green
    Write-Host ""
    
    # Beispiele f?r Pfad-Verwendung
    Write-Host "PFAD-BEISPIELE:" -ForegroundColor Cyan
    
    # Basis-Verzeichnisse
    $logDir = Get-CertWebServicePath -PathName "LogDirectory"
    Write-Host "  Log-Verzeichnis: $logDir" -ForegroundColor White
    
    $scriptsDir = Get-CertWebServicePath -PathName "ScriptsDirectory"  
    Write-Host "  Scripts-Verzeichnis: $scriptsDir" -ForegroundColor White
    
    $networkShare = Get-CertWebServicePath -PathName "NetworkShare"
    Write-Host "  Network-Share: $networkShare" -ForegroundColor White
    
    # Script-Pfade
    $mainScript = Get-CertWebServicePath -PathName "MainScript"
    Write-Host "  Haupt-Script: $mainScript" -ForegroundColor White
    
    $setupScript = Get-CertWebServicePath -PathName "SetupScript"
    Write-Host "  Setup-Script: $setupScript" -ForegroundColor White
    
    # Konfigurationswerte
    Write-Host ""
    Write-Host "KONFIGURATIONSWERTE:" -ForegroundColor Cyan
    Write-Host "  HTTP-Port: $($config.WebService.HttpPort)" -ForegroundColor White
    Write-Host "  HTTPS-Port: $($config.WebService.HttpsPort)" -ForegroundColor White
    Write-Host "  Update-Intervall: $($config.WebService.UpdateIntervalMinutes) Min" -ForegroundColor White
    Write-Host "  Log-Level: $($config.Logging.LogLevel)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "VERWENDUNG IN SCRIPTS:" -ForegroundColor Yellow
    Write-Host @"
# Am Anfang jedes Scripts:
. "`$PSScriptRoot\Get-CertWebServicePaths.ps1"
`$config = Get-CertWebServiceConfig

# Pfade verwenden:
`$logPath = Get-CertWebServicePath -PathName "LogDirectory"
`$networkShare = Get-CertWebServicePath -PathName "NetworkShare"

# Konfigurationswerte verwenden:
`$port = `$config.WebService.HttpPort
`$logLevel = `$config.Logging.LogLevel
"@ -ForegroundColor Gray
    
    Write-Host ""
    Write-Host " Alle Scripts sollten diese Methode verwenden!" -ForegroundColor Green
}

# F?hre Beispiel aus
Example-UseCentralPaths
