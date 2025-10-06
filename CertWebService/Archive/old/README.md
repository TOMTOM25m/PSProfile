# Veraltete Scripts - Archiv

Dieses Verzeichnis enthält alle Scripts und Dateien aus der alten CertWebService-Struktur, die durch die Vereinfachung ersetzt wurden.

## 📁 Archivierte Scripts

### Installation Scripts (ersetzt durch Setup.ps1)
- `Install-CertificateWebService.ps1` - Ursprüngliche Installation
- `Install-CertificateWebService-Clean.ps1` - Bereinigte Version
- `Install-CertWebService-Safe.ps1` - Sichere Installation
- `Install-CertWebServiceTask.ps1` - Task-Installation
- `Install-CertWebServiceTask-Clean.ps1` - Bereinigte Task-Installation
- `Install.bat` - Batch-Installation

### Deployment Scripts (ersetzt durch Update.ps1)
- `Deploy-CertWebService.ps1` - Ursprüngliches Deployment
- `Deploy-CertWebService-Simple.ps1` - Vereinfachtes Deployment
- `Deploy-Simple.ps1` - Einfaches Deployment
- `Distribute-CertWebService.ps1` - Verteilungs-Script
- `Update-CertificateWebService.ps1` - Update-Script

### System Scripts (in Setup.ps1 integriert)
- `Setup-ScheduledTask-CertScan.ps1` - Task-Einrichtung
- `Setup-CertWebService-System.ps1` - System-Setup
- `Manage-CertWebServiceTask.ps1` - Task-Verwaltung

### Dokumentation (archiviert)
- `README.txt` - Alte README
- `VERSION.txt` - Alte Versionsdatei
- `DEPLOYMENT-README.md` - Alte Deployment-Dokumentation

## 🔄 Migration zur neuen Struktur

| Alt | Neu | Beschreibung |
|-----|-----|--------------|
| `Install-*.ps1` (6 Scripts) | `Setup.ps1` | Vereinfachte Installation |
| `Deploy-*.ps1` (4 Scripts) | `Update.ps1` | Einheitliche Updates |
| `Manage-*.ps1` (1 Script) | `Remove.ps1` | Saubere Deinstallation |

## ⚠️ Wichtiger Hinweis

Diese Scripts sind **archiviert** und werden nicht mehr gepflegt. Verwenden Sie die neuen Scripts:

- **Setup.ps1** - Für neue Installationen
- **Update.ps1** - Für Updates und Wartung  
- **Remove.ps1** - Für Deinstallationen

Die archivierten Scripts bleiben nur zur Referenz und für eventuelle Rollback-Szenarien erhalten.

## 📅 Archivierungsdatum

Scripts archiviert am: 29. September 2025
Vereinfachung abgeschlossen: CertWebService v2.0.0

---
*Diese Scripts wurden im Rahmen der CertWebService-Vereinfachung archiviert.*