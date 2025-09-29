# SSL-Port-Demo-Final.ps1
# Demonstration der SSL-Port-Konfiguration
# Author: Flecki Garnreiter

Write-Host "=== SSL-Port-Konfiguration Demonstration ===" -ForegroundColor Cyan

# Konfiguration laden
$ConfigPath = "f:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

Write-Host ""
Write-Host "Aktuelle Konfiguration:" -ForegroundColor Yellow
Write-Host "Standard-Port: $($Config.Certificate.Port)"
Write-Host "Auto-Port-Detection: $($Config.Certificate.EnableAutoPortDetection)"
Write-Host "SSL-Ports: $($Config.Certificate.CommonSSLPorts -join ', ')"
Write-Host ""

Write-Host "Port 9443 ist bereits konfiguriert!" -ForegroundColor Green
Write-Host "Die Auto-Port-Detection wird diese Ports in folgender Reihenfolge testen:"
foreach ($port in $Config.Certificate.CommonSSLPorts) {
    Write-Host "  - Port $port" -ForegroundColor Gray
}

Write-Host ""
Write-Host "GUI-Konfiguration in der Setup-GUI:" -ForegroundColor Yellow
Write-Host "Tab: 'Certificate Settings'" -ForegroundColor Green
Write-Host "  [x] Auto Port Detection"
Write-Host "  SSL-Ports: 443,9443,8443,4443,10443,8080,8081"

Write-Host ""
Write-Host "Demonstration abgeschlossen." -ForegroundColor Cyan
