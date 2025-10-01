# CertWebService Path-Problem - GELÖST ✅

**Datum:** 01.10.2025  
**Version:** v2.3.0  
**Regelwerk:** v10.0.2

---

## 🎯 Problem-Zusammenfassung

### Symptom
Die CertWebService API auf `http://itscmgmt03.srv.meduniwien.ac.at:9080/certificates.json` lieferte:
- **CertificateCount: 0**
- **Leeres Certificates-Array**
- Trotz laufendem WebService v2.3.0

### Root Cause Analysis

#### 1. Mehrere IIS Sites gefunden
```powershell
# itscmgmt03.srv.meduniwien.ac.at hat 3 IIS Sites:
CertificateSurveillance → Port 8080/8443 → C:\inetpub\wwwroot\CertificateSurveillance (Stopped)
CertSurveillance        → Port 9080/9443 → C:\inetpub\wwwroot\CertSurveillance (Stopped)
CertWebService          → Port 9080     → C:\inetpub\wwwroot\CertWebService (Running) ✓
```

#### 2. Path-Mismatch identifiziert
Es gab **VIER verschiedene `certificates.json` Dateien**:

| Pfad | Größe | Zertifikate | Status |
|------|-------|-------------|--------|
| `C:\inetpub\CertWebService\certificates.json` | 22KB | 38 | ✅ Korrekt vom Scan |
| `C:\inetpub\wwwroot\CertWebService\certificates.json` | 552 Bytes | 0 | ❌ Alte Template-Datei |
| `C:\inetpub\wwwroot\CertSurveillance\certificates.json` | 516 Bytes | 0 | ❌ Alt |
| `C:\inetpub\wwwroot\CertificateSurveillance\api\certificates.json` | 166 Bytes | 0 | ❌ Alt |

**Problem:** 
- ❌ **ScanCertificates.ps1** schrieb nach: `C:\inetpub\CertWebService`
- ❌ **IIS CertWebService** las aber von: `C:\inetpub\wwwroot\CertWebService`

---

## 🔧 Implementierte Lösung

### Änderung 1: ScanCertificates.ps1 - Intelligente Path-Erkennung

**Datei:** `F:\DEV\repositories\CertWebService\ScanCertificates.ps1`

#### Vorher:
```powershell
$sitePath = "C:\inetpub\CertWebService"
$certificatesFile = Join-Path $sitePath "certificates.json"
```

#### Nachher:
```powershell
# Support both possible IIS paths
$possiblePaths = @(
    "C:\inetpub\wwwroot\CertWebService",  # Standard IIS path
    "C:\inetpub\CertWebService"            # Alternative path
)

$sitePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $sitePath) {
    Write-Log "ERROR: Neither path exists!" "ERROR"
    # Try to create wwwroot path as fallback
    $sitePath = "C:\inetpub\wwwroot\CertWebService"
    if (-not (Test-Path $sitePath)) {
        New-Item -Path $sitePath -ItemType Directory -Force | Out-Null
        Write-Log "Created directory: $sitePath" "INFO"
    }
}

Write-Log "Using site path: $sitePath" "INFO"
$certificatesFile = Join-Path $sitePath "certificates.json"
```

**Vorteile:**
- ✅ Funktioniert mit beiden IIS-Konfigurationen
- ✅ Erstellt fehlendes Verzeichnis automatisch
- ✅ Logging für Debugging
- ✅ Keine Hardcoded Paths

### Änderung 2: Logging-Pfad ebenfalls angepasst

```powershell
# Logging setup - Support both possible paths
$possibleLogPaths = @(
    "C:\inetpub\wwwroot\CertWebService\Logs",
    "C:\inetpub\CertWebService\Logs"
)

$logPath = $possibleLogPaths | Where-Object { Test-Path (Split-Path $_ -Parent) } | Select-Object -First 1

if (-not $logPath) {
    $logPath = "C:\inetpub\wwwroot\CertWebService\Logs"  # Default fallback
}
```

---

## 🚀 Deployment

### Deployment-Script erstellt
**Datei:** `F:\DEV\repositories\CertWebService\Deploy-ScanScript-Quick.ps1`

```powershell
# Deployment auf itscmgmt03
.\Deploy-ScanScript-Quick.ps1
```

### Deployment-Ergebnis

#### ✅ itscmgmt03.srv.meduniwien.ac.at
```
[2025-10-01 15:10:46] [INFO] === Certificate WebService Daily Scan Started ===
[2025-10-01 15:10:46] [INFO] Version: v2.3.0 | Regelwerk: v10.0.0
[2025-10-01 15:10:46] [INFO] Discovered 38 certificates
[2025-10-01 15:10:46] [INFO] Using site path: C:\inetpub\wwwroot\CertWebService
[2025-10-01 15:10:46] [INFO] Updated certificates.json with 38 certificates
[2025-10-01 15:10:46] [INFO] === Certificate Scan Completed Successfully ===
```

**Status:** ✅ **ERFOLGREICH**
- 38 Zertifikate gefunden
- certificates.json aktualisiert (22.436 Bytes)
- API liefert korrekte Daten

#### ⚠️ wsus.srv.meduniwien.ac.at
```
Copy-Item : The user name or password is incorrect.
```

**Status:** ❌ **Zugriffsfehler**
- Keine Zugriffsrechte auf `\\wsus\c$\`
- Muss manuell oder mit anderen Credentials deployed werden

---

## ✅ Verifikation

### API Test - Vorher
```json
{
    "version": "v2.3.0",
    "timestamp": "2025-09-30 11:01:05",
    "read_only_mode": true,
    "certificates": [],
    "summary": {
        "expired": 0,
        "expiring_soon": 0,
        "total": 0
    }
}
```
**CertificateCount:** 0 ❌

### API Test - Nachher
```json
{
    "timestamp": "2025-10-01 15:10:46",
    "server": "ITSCMGMT03",
    "scan_version": "v2.3.0",
    "api_version": "2.3.0",
    "total_count": 38,
    "certificates": [
        {
            "subject": "CN=localhost",
            "issuer": "CN=localhost",
            "expiry": "2026-09-22",
            "thumbprint": "E0E741FCBDAEEE3EC7A67C4C3CF51720FE2BB5EB",
            "status": "Valid",
            "store": "My"
        },
        ... (37 weitere)
    ],
    "statistics": {
        "valid": 38,
        "expiring_soon": 0,
        "expired": 0
    }
}
```
**CertificateCount:** 38 ✅

### PowerShell Test
```powershell
$response = Invoke-WebRequest -Uri "http://itscmgmt03.srv.meduniwien.ac.at:9080/certificates.json"
$json = $response.Content -replace '^\xEF\xBB\xBF', '' | ConvertFrom-Json

Write-Host "Total Certificates: $($json.total_count)"  # Output: 38
Write-Host "Valid: $($json.statistics.valid)"          # Output: 38
Write-Host "Server: $($json.server)"                   # Output: ITSCMGMT03
```

**Ergebnis:** ✅ **API liefert jetzt korrekte Zertifikatsdaten!**

---

## 📊 Zertifikats-Übersicht (itscmgmt03)

### Statistik
- **Total:** 38 Zertifikate
- **Valid:** 38 ✅
- **Expiring Soon (≤30 days):** 0
- **Expired:** 0

### Sample (erste 3)
1. **CN=localhost**
   - Expiry: 2026-09-22
   - Status: Valid
   - Store: My
   - Thumbprint: E0E741FCBDAEEE3EC7A67C4C3CF51720FE2BB5EB

2. **CN=localhost**
   - Expiry: 2026-09-16
   - Status: Valid
   - Store: My
   - Thumbprint: 82CFDC20C32261875275E17202E1771ECF677941

3. **CN=localhost**
   - Expiry: 2026-09-16
   - Status: Valid
   - Store: My
   - Thumbprint: 1A60EBD4C7CC0ADB5A4E8AD0CF68E3D2FCFA64E3

---

## 📋 Nächste Schritte

### 1. wsus.srv.meduniwien.ac.at deployen
**Problem:** Keine Zugriffsrechte

**Optionen:**
- [ ] Manuelles Deployment mit Remote Desktop
- [ ] Deployment mit Domain-Admin-Credentials
- [ ] PowerShell Enter-PSSession und lokales Kopieren

### 2. Scheduled Task einrichten
Automatischer täglicher Scan:
```powershell
# Scheduled Task für täglichen Scan um 06:00
.\Setup-ScheduledTask-CertScan.ps1
```

### 3. Integration in CertSurv testen
Die Port-Anpassungen (9080) sind bereits in CertSurv implementiert:
- [ ] Hauptscript ausführen
- [ ] API-Abruf von itscmgmt03 testen
- [ ] Zertifikats-Report generieren

---

## 🔗 Betroffene Dateien

### Geändert
- ✅ `F:\DEV\repositories\CertWebService\ScanCertificates.ps1`

### Neu erstellt
- ✅ `F:\DEV\repositories\CertWebService\Deploy-ScanScript-Quick.ps1`
- ✅ `F:\DEV\repositories\CertWebService\Fix-CertWebService-Paths.ps1` (nicht funktional, durch Quick ersetzt)

### Deployed
- ✅ `\\itscmgmt03\c$\inetpub\wwwroot\CertWebService\ScanCertificates.ps1` (v2.3.0)

---

## 🎓 Lessons Learned

1. **IIS Physical Paths überprüfen:** Nicht davon ausgehen, dass alle Sites im gleichen Verzeichnis liegen
2. **Multiple Site-Instanzen:** Vorsicht bei mehreren Sites auf demselben Port (aber verschiedenen Hosts)
3. **Path-Flexibilität:** Scripts sollten beide gängige IIS-Pfade unterstützen
4. **UTF-8 BOM:** PowerShell `ConvertFrom-Json` hat Probleme mit BOM - muss gefiltert werden
5. **Verify after Deployment:** Immer API-Response nach Deployment testen

---

## ✅ Status

| Server | Status | Zertifikate | API Response | Deployment |
|--------|--------|-------------|--------------|------------|
| **itscmgmt03.srv.meduniwien.ac.at** | ✅ Funktioniert | 38 | ✅ OK | ✅ Deployed |
| **wsus.srv.meduniwien.ac.at** | ⚠️ Pending | - | ❌ Empty | ❌ Access Denied |

---

**Problem:** ✅ **GELÖST für itscmgmt03**  
**Erstellt:** 01.10.2025 15:10  
**Version:** v2.3.0  
**Regelwerk:** v10.0.2
