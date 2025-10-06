# 🎯 Config-Integration für Excel-basierte Updates

## ✅ Was wurde erweitert

Das Excel-Update-System liest jetzt automatisch die **Excel-Pfad-Konfiguration** aus Ihrer existierenden CertSurv-Config-Datei!

### 📍 Config-Datei Location

```
F:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json
```

### 🔧 Relevante Config-Felder

```json
{
  "ExcelFilePath": "\\\\itscmgmt03.srv.meduniwien.ac.at\\iso\\WindowsServerListe\\Serverliste2025.xlsx",
  "ExcelWorksheet": "Serversliste2025"
}
```

## 🚀 Sofortiger Test der Config-Integration

```powershell
# Test ob Config-Integration funktioniert
.\Test-Config-Integration.ps1
```

**Was dieser Test prüft:**

- ✅ Config-Datei lesbar
- ✅ Excel-Pfad in Config vorhanden  
- ✅ Excel-Datei am konfigurierten Pfad erreichbar
- ✅ ImportExcel-Modul verfügbar
- ✅ Grundlegendes Excel-Lesen funktioniert

## 📊 Automatische Pfad-Erkennung

Das System arbeitet jetzt mit **intelligenten Fallbacks**:

### 1. **Primär: Config-Datei** (Bevorzugt)

```
Config-Datei → ExcelFilePath + ExcelWorksheet
```

### 2. **Fallback: Parameter** (Falls Config fehlt)

```
.\Excel-Update-Launcher.ps1 -ExcelPath "C:\Custom\Path.xlsx"
```

### 3. **Fallback: Hardcoded** (Notfall)

```
Standard: F:\DEV\repositories\Data\Serverliste2025.xlsx
```

## 🎯 Verwendung - Noch einfacher geworden

### Standard-Ausführung (Config-basiert)

```powershell
# Verwendet automatisch Excel-Pfad aus Config
.\Excel-Update-Launcher.ps1 -Mode Analyze
```

### Mit Custom-Config

```powershell  
# Verwendet anderen Config-Pfad
.\Update-FromExcel-MassUpdate.ps1 -ConfigPath "C:\Custom\Config.json"
```

### Mit direktem Excel-Pfad

```powershell
# Überschreibt Config-Pfad
.\Update-FromExcel-MassUpdate.ps1 -ExcelPath "C:\Custom\Servers.xlsx"
```

## 🔧 Config-Vorteile

### ✅ **Zentrale Konfiguration**

- Ein Ort für alle Excel-Einstellungen
- Konsistent mit CertSurv-System
- Einfache Wartung

### ✅ **Netzwerk-Share-Support**  

- Automatische UNC-Pfad-Unterstützung
- `\\server\share\path.xlsx` wird korrekt behandelt
- Netzwerk-Connectivity-Tests integriert

### ✅ **Robuste Fallbacks**

- Config-Fehler → Automatischer Fallback
- Netzwerk-Probleme → Lokale Alternative  
- Transparente Fehlerbehandlung

## 📂 Ihre Config-Struktur

Aus Ihrer existierenden Config werden automatisch gelesen:

| Config-Feld | Zweck | Ihr Wert |
|-------------|-------|----------|
| `ExcelFilePath` | Excel-Datei-Pfad | `\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx` |
| `ExcelWorksheet` | Arbeitsblatt-Name | `Serversliste2025` |
| `ExcelHeaderRow` | Header-Zeile | `2` |
| `ExcelStartRow` | Start-Zeile | `4` |

## 🎉 Sofort testen

```powershell
# 1. Config-Integration testen (2 Minuten)
.\Test-Config-Integration.ps1

# 2. Excel-basierte Analyse starten (5 Minuten)  
.\Excel-Update-Launcher.ps1 -Mode Analyze
```

## 🔄 Migration von hartem Pfad

**Vorher:**

```powershell
# Hardcoded path
$excelPath = "F:\DEV\repositories\Data\Serverliste2025.xlsx"
```

**Nachher:**

```powershell
# Config-based with fallback
$config = Get-Content $configPath | ConvertFrom-Json
$excelPath = $config.ExcelFilePath
```

## 🎯 Das bedeutet für Sie

### ✅ **Keine Pfad-Anpassungen mehr nötig**

- System liest Ihren Excel-Pfad automatisch aus CertSurv-Config
- Konsistent mit Ihrem existierenden Setup

### ✅ **Netzwerk-Share funktioniert automatisch**  

- `\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx`
- Automatische Netzwerk-Tests und Fallbacks

### ✅ **Ein zentraler Ort für alle Einstellungen**

- Ändern Sie Excel-Pfad nur in der Config-Datei
- Alle Skripte verwenden automatisch den neuen Pfad

**Das System ist jetzt noch intelligenter und wartungsfreundlicher geworden!** 🚀
