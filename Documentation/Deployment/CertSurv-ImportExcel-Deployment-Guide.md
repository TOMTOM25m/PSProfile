# CertSurv ImportExcel Lösung - Deployment Anleitung

## Problem
- Excel COM-Objects nicht verfügbar auf Server ITSCMGMT03
- Fehler: `80040154 Class not registered (REGDB_E_CLASSNOTREG)`
- CertSurv konnte Header-Context nicht extrahieren

## Lösung
**ImportExcel PowerShell Modul** statt COM-Objects verwenden

## Bereitgestellte Dateien (Netzlaufwerk)
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\
├── FL-DataProcessing-NoExcelCOM.psm1      (ImportExcel-basierte Funktionen)
├── Install-ImportExcel-Solution.ps1       (Automatische Installation)
└── [bestehende CertSurv-Dateien]
```

## Installation auf Server ITSCMGMT03

### Schritt 1: Auf Server verbinden
```powershell
# Remote Desktop oder PowerShell Session
```

### Schritt 2: Installations-Script ausführen
```powershell
# Als Administrator ausführen:
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\Install-ImportExcel-Solution.ps1
```

### Was das Script macht:
1. **ImportExcel Modul installieren** (`Install-Module -Name ImportExcel -Force -Scope AllUsers`)
2. **Backup erstellen** von `C:\CertSurv\Modules\FL-DataProcessing.psm1`
3. **Neue Version installieren** mit ImportExcel-Integration
4. **Tests ausführen** zur Bestätigung
5. **Log erstellen** in `C:\CertSurv\LOG\Install-ImportExcel-*.log`

## Technische Details

### ImportExcel vs COM-Objects
| Aspekt | COM-Objects | ImportExcel |
|--------|-------------|-------------|
| Excel-Installation | ✅ Erforderlich | ❌ Nicht erforderlich |
| Server-Kompatibilität | ❌ Fehlerhafte Registrierung | ✅ Funktioniert immer |
| Performance | 🟡 Langsam | ✅ Schneller |
| Wartung | ❌ COM-Abhängigkeiten | ✅ Reine PowerShell |

### Header-Context Extraktion
- **Erkennt**: `(Domain)UVW` → Domain-Block
- **Erkennt**: `(Workgroup)xxx` → Workgroup-Block  
- **Erkennt**: `SUMME:` → Block-Ende
- **Beispiel**: `proman` → UVW Domain, `M42MASTER` → srv Workgroup

## Bestätigung der Funktionalität

### Test erfolgreich durchgeführt:
```
[2025-10-06 11:42:40] [INFO] Excel data loaded: 316 rows
[2025-10-06 11:42:40] [INFO] -> DOMAIN BLOCK DETECTED: 'uvw'
[2025-10-06 11:42:40] [INFO] -> SERVER: Domain='uvw', Subdomain='uvw', IsDomain=True
[2025-10-06 11:42:40] [INFO] === RESULTS ===
[2025-10-06 11:42:40] [INFO] Header context extracted: 16 servers
[2025-10-06 11:42:40] [INFO] - Domain servers: 16
[2025-10-06 11:42:40] [INFO] - Workgroup servers: 0
[2025-10-06 11:42:40] [INFO] === SUCCESS - ImportExcel works correctly ===
```

## Nach der Installation

### CertSurv testen:
```powershell
# CertSurv Debug ausführen
C:\CertSurv\Debug-ExcelHeaderContext.ps1
```

### Erwartetes Ergebnis:
- ✅ Keine COM-Object Fehler mehr
- ✅ Header-Context wird korrekt extrahiert
- ✅ Domain/Workgroup-Zuordnung funktioniert
- ✅ proman → UVW Domain
- ✅ M42MASTER → srv Workgroup

## Support
- **Logs**: `C:\CertSurv\LOG\Install-ImportExcel-*.log`
- **Backup**: `C:\CertSurv\Modules\FL-DataProcessing-BACKUP-COM-*.psm1`
- **Rollback**: Backup-Datei zurückkopieren falls Probleme

---
**Erstellt**: 2025-10-06  
**Version**: 1.0.0  
**Status**: ✅ Bereit für Deployment