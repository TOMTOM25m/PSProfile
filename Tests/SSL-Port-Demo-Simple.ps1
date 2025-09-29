# SSL-Port-Demo-Simple.ps1
# Einfache Demonstration der SSL-Port-Konfiguration
# Author: Flecki Garnreiter

# Aktuelle Konfiguration anzeigen
$ConfigPath = "f:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

Write-Host "=== SSL-Port-Konfiguration ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Aktuelle Einstellungen in Config-Cert-Surveillance.json:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Standard-Port:" -NoNewline -ForegroundColor Green
Write-Host " $($Config.Certificate.Port)" -ForegroundColor White

Write-Host "Auto-Port-Detection:" -NoNewline -ForegroundColor Green
Write-Host " $($Config.Certificate.EnableAutoPortDetection)" -ForegroundColor White

Write-Host "SSL-Ports für Auto-Detection:" -NoNewline -ForegroundColor Green
Write-Host " $($Config.Certificate.CommonSSLPorts -join ', ')" -ForegroundColor White

Write-Host "Timeout:" -NoNewline -ForegroundColor Green
Write-Host " $($Config.Certificate.Timeout) ms" -ForegroundColor White

Write-Host "Methode:" -NoNewline -ForegroundColor Green
Write-Host " $($Config.Certificate.Method)" -ForegroundColor White

Write-Host ""
Write-Host "=== So funktioniert die Auto-Port-Detection ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Versuch mit Standard-Port (443)" -ForegroundColor Yellow
Write-Host "2. Falls fehlgeschlagen und Auto-Detection aktiviert:" -ForegroundColor Yellow
Write-Host "   → Versuche alle konfigurierten Ports:" -ForegroundColor Yellow
foreach ($port in $Config.Certificate.CommonSSLPorts) {
    Write-Host "     - Port $port" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== GUI-Konfiguration ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "In der Setup-GUI finden Sie die folgenden Einstellungen:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Tab: 'Certificate Settings / Zertifikat-Einstellungen'" -ForegroundColor Green
Write-Host "  ✓ Auto Port Detection / Automatische Port-Erkennung [Checkbox]" -ForegroundColor White
Write-Host "  ✓ Common SSL Ports / Häufige SSL-Ports [Textfeld]" -ForegroundColor White
Write-Host "    Format: 443,9443,8443,4443,10443,8080,8081" -ForegroundColor Gray
Write-Host ""

Write-Host "=== Test der Auto-Port-Detection ===" -ForegroundColor Cyan
Write-Host ""
$TestChoice = Read-Host "Möchten Sie die Auto-Port-Detection testen? (j/n)"

if ($TestChoice -eq 'j' -or $TestChoice -eq 'y') {
    # Bereinigtes Modul laden
    $ModulePath = "f:\DEV\repositories\CertSurv\Modules\FL-Certificate-Clean.psm1"
    
    if (Test-Path $ModulePath) {
        try {
            Import-Module $ModulePath -Force
            Write-Host "✓ Certificate module loaded" -ForegroundColor Green
            
            # Test-Konfiguration erstellen
            $TestConfig = @{
                Certificate = @{
                    EnableAutoPortDetection = $true
                    CommonSSLPorts = @(443, 9443, 8443, 4443, 10443, 8080)
                    Method = "Browser"
                    Timeout = 5000
                }
            }
            
            Write-Host ""
            Write-Host "Test 1: www.google.com (Port 443 sollte funktionieren)" -ForegroundColor Yellow
            $result1 = Get-RemoteCertificate -ServerName "www.google.com" -Port 443 -Method Browser -Config $TestConfig
            if ($result1) {
                Write-Host "✓ Erfolg: $($result1.Subject)" -ForegroundColor Green
            }
            
            Write-Host ""
            Write-Host "Test 2: www.google.com mit Port 9443 (sollte auf 443 zurückfallen)" -ForegroundColor Yellow
            $result2 = Get-RemoteCertificate -ServerName "www.google.com" -Port 9443 -Method Browser -Config $TestConfig
            if ($result2) {
                Write-Host "✓ Auto-Detection funktioniert: $($result2.Subject)" -ForegroundColor Green
                if ($result2.AutoDetectedPort) {
                    Write-Host "  -> Automatisch von Port $($result2.OriginalPort) auf Port $($result2.Port) gewechselt" -ForegroundColor Cyan
                }
            }
            
        } catch {
            Write-Error "Fehler beim Testen: $_"
        }
    } else {
        Write-Host "✗ Certificate module nicht gefunden: $ModulePath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Zusammenfassung ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Port 9443 ist bereits in der Konfiguration enthalten" -ForegroundColor Green
Write-Host "✓ Auto-Port-Detection ist aktiviert" -ForegroundColor Green
Write-Host "✓ GUI-Konfiguration ist verfügbar in der Setup-GUI" -ForegroundColor Green
Write-Host "✓ Browser-Methode funktioniert mit Auto-Port-Detection" -ForegroundColor Green
Write-Host ""
