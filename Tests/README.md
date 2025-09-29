# Certificate Surveillance System - Test Scripts

Dieser Ordner enthält alle Test-Scripts für das Certificate Surveillance System.

## 📁 Test-Script Kategorien

### FQDN & Netzwerk Tests
- `Test-FQDN-Fallback.ps1` - Test der intelligenten FQDN-Konstruktion mit Ping-Fallback
- `Test-Complete-Processing.ps1` - Vollständiger Excel-Verarbeitungstest mit FQDN-Fallback
- `Test-FQDN-Minimal.ps1` - Minimaler FQDN-Konstruktionstest
- `Test-FQDN-Fix.ps1` - FQDN-Korrektur Tests
- `Test-FQDN-Fix-Clean.ps1` - Bereinigte FQDN-Tests

### Subdomain & Header Tests
- `Test-Header-Extraction.ps1` - Test der Header-basierten Subdomain-Extraktion
- `Test-IntelligentSubdomainDetection.ps1` - Intelligente Subdomain-Erkennung
- `Test-SubdomainSimple.ps1` - Einfache Subdomain-Tests
- `Test-IntelligentFQDN.ps1` - Intelligente FQDN-Konstruktion

### Domain Server Tests
- `Test-DomainServerIdentification.ps1` - Domain-Server-Identifikation
- `Test-DomainServerIdentification-Fixed.ps1` - Korrigierte Domain-Server-Tests
- `Test-DomainSimple.ps1` - Einfache Domain-Tests

### Excel Processing Tests
- `Test-CompleteExcelStructure.ps1` - Vollständige Excel-Struktur Tests
- `Test-SummaryFilter.ps1` - Excel-Summary-Filter Tests
- `Test-EnhancedFiltering.ps1` - Erweiterte Excel-Filterung
- `Test-UpdateWorkgroupServer.ps1` - Workgroup-Server Update Tests

### Certificate & Port Tests
- `Test-CertificateFirstProcessing.ps1` - Zertifikat-erste-Verarbeitung Tests
- `Test-AlternativePort.ps1` - Alternative Port Tests
- `Test-AutoPortDetection.ps1` - Automatische Port-Erkennung
- `Test-AutoPortDetection-Clean.ps1` - Bereinigte Port-Erkennung Tests

## 🚀 Verwendung

### Einzelne Tests ausführen:
```powershell
cd f:\DEV\repositories\Tests
.\Test-FQDN-Fallback.ps1
```

### Alle Tests ausführen:
```powershell
cd f:\DEV\repositories\Tests
Get-ChildItem -Filter "Test-*.ps1" | ForEach-Object { 
    Write-Host "=== Running $($_.Name) ===" -ForegroundColor Yellow
    & $_.FullName
    Write-Host ""
}
```

## 📝 Test-Entwicklung

### Neue Tests erstellen:
1. Dateiname: `Test-[Funktionalität].ps1`
2. Header mit Zweck, Autor und Datum
3. Import der benötigten Module aus `../CertSurv/Modules/`
4. Aussagekräftige Test-Ausgaben mit Farben

### Beispiel Test-Struktur:
```powershell
# Test [Funktionalität]
# Purpose: [Beschreibung]
# Author: Certificate Surveillance System
# Date: [Datum]

$ModulePath = "f:\DEV\repositories\CertSurv\Modules"
Import-Module "$ModulePath\[ModuleName].psm1" -Force

Write-Host "=== [Test Name] ===" -ForegroundColor Green
# Test-Code hier
Write-Host "=== Test Complete ===" -ForegroundColor Green
```

## 🔧 Wartung

- **Veraltete Tests**: Regelmäßig überprüfen und archivieren
- **Abhängigkeiten**: Tests sollten Module aus `../CertSurv/Modules/` verwenden
- **Dokumentation**: README bei neuen Test-Kategorien aktualisieren

---
**Version**: v1.0.0  
**Datum**: September 9, 2025  
**Regelwerk**: v9.3.0
