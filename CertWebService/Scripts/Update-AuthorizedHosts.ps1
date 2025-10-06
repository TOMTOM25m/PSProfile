#Requires -Version 5.1

<#
.SYNOPSIS
Update-AuthorizedHosts.ps1 - Dynamische Authorized Hosts Konfiguration
.DESCRIPTION
Aktualisiert die AllowedHosts in den Konfigurationsdateien mit dem aktuellen System
Regelwerk v10.0.2 konform | Stand: 02.10.2025
#>

param(
    [string]$ConfigPath = "Config\Config-CertWebService.json",
    [string]$CertSurvConfigPath = "Config\CertSurv-Config.json"
)

Write-Host "=== UPDATE AUTHORIZED HOSTS ===" -ForegroundColor Green
Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray
Write-Host ""

# Sammle System-Informationen
$computerName = $env:COMPUTERNAME
$fqdn = "$computerName.srv.meduniwien.ac.at"

Write-Host "System-Informationen:" -ForegroundColor Cyan
Write-Host "  Computer Name: $computerName" -ForegroundColor White
Write-Host "  FQDN: $fqdn" -ForegroundColor White

# Standard Authorized Hosts (immer dabei)
$standardHosts = @(
    "localhost",
    "127.0.0.1",
    "::1",
    $computerName,
    $fqdn,
    "ITSCMGMT03.srv.meduniwien.ac.at",
    "ITSC020.cc.meduniwien.ac.at", 
    "itsc049.uvw.meduniwien.ac.at"
)

Write-Host "`nStandard Authorized Hosts:" -ForegroundColor Cyan
$standardHosts | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# Aktualisiere Config-CertWebService.json
if (Test-Path $ConfigPath) {
    try {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        $config.AccessControl.AllowedHosts = $standardHosts
        $config | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding UTF8
        Write-Host "`n $ConfigPath aktualisiert" -ForegroundColor Green
    } catch {
        Write-Host "`n Fehler bei $ConfigPath : $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n $ConfigPath nicht gefunden" -ForegroundColor Red
}

# Aktualisiere CertSurv-Config.json  
if (Test-Path $CertSurvConfigPath) {
    try {
        $certSurvConfig = Get-Content $CertSurvConfigPath | ConvertFrom-Json
        $certSurvConfig.Security.AllowedHosts = $standardHosts
        $certSurvConfig | ConvertTo-Json -Depth 10 | Out-File $CertSurvConfigPath -Encoding UTF8
        Write-Host " $CertSurvConfigPath aktualisiert" -ForegroundColor Green
    } catch {
        Write-Host " Fehler bei $CertSurvConfigPath : $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host " $CertSurvConfigPath nicht gefunden" -ForegroundColor Red
}

Write-Host "`n Authorized Hosts Update abgeschlossen" -ForegroundColor Green
Write-Host "Alle Standard-Hosts (localhost, FQDN, etc.) sind jetzt konfiguriert" -ForegroundColor White
